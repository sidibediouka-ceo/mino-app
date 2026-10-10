"""Trains Mino's garment classifier and exports it for Core ML.

Data
- The Clothing Dataset by Alexey Grigorev (CC0 1.0, public domain):
  https://github.com/alexeygrigorev/clothing-dataset, about 5,000 photos.
- Mino's own catalogue photos (children's clothes on white), listed in a CSV of `path,class`:
  the closest to what parents photograph, and the only tights.

Model: MobileNetV3-Large pre-trained on ImageNet (timm, Apache 2.0), fine-tuned on the
classes below. The classes are visual families; MinoKit maps them to garment categories and
combines them with the outline (GarmentShape) and Apple's classifier.

Usage:
    python3 design/classifier/train.py --dataset <clothing-dataset> --weights <mobilenetv3.pth> \
        --photos <photos.csv> --out Mino/Resources/MinoGarmentClassifier.mlmodel
    Add --holdout <photos.csv> to measure on catalogue photos left out of training, and
    --init <model.pth> to start from an earlier run.
"""
import argparse
import csv
import random
from collections import Counter
from pathlib import Path

import torch
import timm
from PIL import Image
from torch import nn
from torch.utils.data import DataLoader, Dataset, WeightedRandomSampler
from torchvision import transforms

CLASSES = ["tshirt", "longsleeve", "knit", "pants", "shorts_skirt", "dress", "outerwear", "shoes", "hat", "bodysuit", "tights"]
DATASET_LABELS = {
    "T-Shirt": "tshirt", "Polo": "tshirt", "Top": "tshirt", "Undershirt": "tshirt",
    "Longsleeve": "longsleeve", "Shirt": "longsleeve", "Blouse": "longsleeve",
    "Hoodie": "knit", "Pants": "pants", "Shorts": "shorts_skirt", "Skirt": "shorts_skirt",
    "Dress": "dress", "Outwear": "outerwear", "Blazer": "outerwear",
    "Shoes": "shoes", "Hat": "hat", "Body": "bodysuit",
}
SIZE = 224
MEAN, STD = (0.485, 0.456, 0.406), (0.229, 0.224, 0.225)


def on_white(path):
    """Mino classifies cut-outs on a white sheet with a margin: prepare transparent photos the same way."""
    image = Image.open(path)
    if image.mode not in ("RGBA", "LA", "P"):
        return image.convert("RGB")
    image = image.convert("RGBA")
    image = image.crop(image.getchannel("A").getbbox())
    side = int(max(image.size) * 1.2)
    sheet = Image.new("RGB", (side, side), "white")
    sheet.paste(image, ((side - image.width) // 2, (side - image.height) // 2), image.getchannel("A"))
    return sheet


class Photos(Dataset):
    def __init__(self, items, transform):
        self.items, self.transform = items, transform

    def __len__(self):
        return len(self.items)

    def __getitem__(self, index):
        path, label = self.items[index]
        return self.transform(on_white(path)), label


def load_items(dataset):
    items = []
    with open(Path(dataset) / "images.csv") as file:
        for row in csv.DictReader(file):
            label = DATASET_LABELS.get(row["label"])
            path = Path(dataset) / "images" / f"{row['image']}.jpg"
            if label and path.exists():
                items.append((path, CLASSES.index(label)))
    return items


def load_photos(listing):
    with open(listing) as file:
        return [(Path(row[0]), CLASSES.index(row[1])) for row in csv.reader(file)]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--dataset", required=True)
    parser.add_argument("--weights", required=True)
    parser.add_argument("--photos", required=True)
    parser.add_argument("--holdout")
    parser.add_argument("--init")
    parser.add_argument("--out", required=True)
    parser.add_argument("--epochs", type=int, default=8)
    args = parser.parse_args()
    random.seed(7)
    torch.manual_seed(7)
    torch.set_num_threads(4)

    items = load_items(args.dataset)
    random.shuffle(items)
    cut = int(len(items) * 0.85)
    train, test = items[:cut], items[cut:]
    # Catalogue photos are few but closest to the app: they weigh like a whole class each.
    photos = load_photos(args.photos)
    train += photos * 4
    holdout = load_photos(args.holdout) if args.holdout else []
    print("train", Counter(CLASSES[label] for _, label in train))
    print("test", Counter(CLASSES[label] for _, label in test))

    augment = transforms.Compose([
        transforms.RandomResizedCrop(SIZE, scale=(0.55, 1.0), ratio=(0.7, 1.4)),
        transforms.RandomHorizontalFlip(),
        transforms.ColorJitter(0.25, 0.25, 0.25, 0.04),
        transforms.RandomGrayscale(0.05),
        transforms.ToTensor(), transforms.Normalize(MEAN, STD),
    ])
    plain = transforms.Compose([
        transforms.Resize((SIZE, SIZE)), transforms.ToTensor(), transforms.Normalize(MEAN, STD),
    ])
    # The app pads each cut-out on a white square sheet before classifying it.
    # Rare classes are drawn as often as frequent ones.
    counts = Counter(label for _, label in train)
    weights = [1 / counts[label] for _, label in train]
    sampler = WeightedRandomSampler(weights, num_samples=len(train), replacement=True)
    train_loader = DataLoader(Photos(train, augment), batch_size=32, sampler=sampler, num_workers=3)
    test_loader = DataLoader(Photos(test, plain), batch_size=64, num_workers=3)
    holdout_loader = DataLoader(Photos(holdout, plain), batch_size=64, num_workers=3) if holdout else None

    model = timm.create_model("mobilenetv3_large_100", pretrained=False)
    model.load_state_dict(torch.load(args.weights, map_location="cpu"))
    model.reset_classifier(len(CLASSES))
    if args.init:
        model.load_state_dict(torch.load(args.init, map_location="cpu"))
    head = list(model.get_classifier().parameters())
    optimizer = torch.optim.AdamW([
        {"params": [p for p in model.parameters() if all(p is not h for h in head)], "lr": 3e-4},
        {"params": head, "lr": 2e-3},
    ], weight_decay=1e-4)
    scheduler = torch.optim.lr_scheduler.CosineAnnealingLR(optimizer, T_max=args.epochs)
    loss_fn = nn.CrossEntropyLoss(label_smoothing=0.1)

    for epoch in range(args.epochs):
        model.train()
        for step, (images, labels) in enumerate(train_loader):
            optimizer.zero_grad()
            loss = loss_fn(model(images), labels)
            loss.backward()
            optimizer.step()
            if step % 40 == 0:
                print(f"epoch {epoch} step {step} loss {loss.item():.3f}", flush=True)
        scheduler.step()
        evaluate(model, test_loader)
        if holdout_loader:
            print("catalogue photos:", end=" ")
            evaluate(model, holdout_loader)

    torch.save(model.state_dict(), Path(args.out).with_suffix(".pth"))
    export(model, args.out)


def evaluate(model, loader):
    model.eval()
    right, total = Counter(), Counter()
    with torch.no_grad():
        for images, labels in loader:
            predictions = model(images).argmax(1)
            for label, prediction in zip(labels.tolist(), predictions.tolist()):
                total[label] += 1
                right[label] += label == prediction
    overall = sum(right.values()) / sum(total.values())
    print(f"accuracy {overall:.3f}", {CLASSES[k]: f"{right[k]}/{total[k]}" for k in sorted(total)}, flush=True)
    return overall


def export(model, out):
    import coremltools as ct
    model.eval()
    traced = torch.jit.trace(model, torch.rand(1, 3, SIZE, SIZE))
    # Core ML feeds 0–255 pixels: scale and normalise inside the model (per-channel bias, mean std).
    scale = 1 / (255 * 0.226)
    bias = [-m / 0.226 for m in MEAN]
    mlmodel = ct.convert(
        traced,
        inputs=[ct.ImageType(name="image", shape=(1, 3, SIZE, SIZE), scale=scale, bias=bias)],
        classifier_config=ct.ClassifierConfig(CLASSES),
        convert_to="neuralnetwork",
        minimum_deployment_target=ct.target.iOS14,
    )
    from coremltools.models.neural_network import quantization_utils
    mlmodel = quantization_utils.quantize_weights(mlmodel, nbits=16)
    mlmodel.short_description = "Mino garment families, from a background-free photo on white."
    mlmodel.license = "Model: MobileNetV3 (timm, Apache 2.0). Data: Clothing Dataset (CC0) and Mino photos."
    mlmodel.save(out)
    print("saved", out)


if __name__ == "__main__":
    main()
