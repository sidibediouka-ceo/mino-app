import MinoKit
import PhotosUI
import SwiftData
import SwiftUI

/// Batch digitisation, validated by exception: pick up to 20 photos (or shoot them in a row),
/// Mino lifts each garment off its background and fills everything in. The parent sees the
/// whole batch at once, fixes only what is flagged or wrong, and adds it all in one tap.
struct AddGarmentsView: View {
    /// `nil` adds to the family boxes.
    let owner: Child?
    let sizing: ChildProfile?
    let onFinish: () -> Void

    @Environment(\.modelContext) private var context
    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var drafts: [GarmentDraft] = []
    @State private var pendingAnalyses = 0
    @State private var savedCount = 0
    @State private var showingCamera = false
    @State private var editing: GarmentDraft?

    var body: some View {
        Group {
            if !drafts.isEmpty {
                review
            } else if pendingAnalyses > 0 {
                ProgressView("Mino détoure vos vêtements…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                sources
            }
        }
        .background(Theme.background)
        .onChange(of: pickerItems) { _, items in
            guard !items.isEmpty else { return }
            pickerItems = []
            Task { await importPhotos(items) }
        }
        .fullScreenCover(isPresented: $showingCamera) {
            CameraPicker { image in
                Task { await analyze(image) }
            }
            .ignoresSafeArea()
        }
        .sheet(item: $editing) { draft in
            DraftEditor(draft: draft, sizing: sizing) { edited in
                if let index = drafts.firstIndex(where: { $0.id == draft.id }) {
                    if let edited { drafts[index] = edited } else { drafts.remove(at: index) }
                }
                editing = nil
            }
        }
    }

    // MARK: Sources

    private var sources: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if savedCount > 0 {
                    Label("\(Formatting.count(savedCount, "vêtement ajouté", "vêtements ajoutés"))", systemImage: "checkmark.circle.fill")
                        .font(.system(.title3, design: .rounded).weight(.bold))
                        .foregroundStyle(Theme.ink)
                } else {
                    Text("Une dizaine de photos suffit pour commencer. Mino détoure et reconnaît chaque vêtement : vous ne corrigez que ce qui le mérite.")
                        .foregroundStyle(Theme.secondaryText)
                }

                PhotosPicker(selection: $pickerItems, maxSelectionCount: 20, matching: .images) {
                    SourceCard(symbol: "photo.on.rectangle.angled", title: "Choisir dans la photothèque", message: "Jusqu'à 20 photos d'un coup")
                }
                .buttonStyle(.plain)

                if CameraPicker.isAvailable {
                    Button { showingCamera = true } label: {
                        SourceCard(symbol: "camera.fill", title: "Prendre en photo", message: "Une photo après l'autre, en rafale")
                    }
                    .buttonStyle(.plain)
                }

                Label("Posé à plat sur un fond uni, le vêtement est détouré parfaitement.", systemImage: "lightbulb.fill")
                    .font(.footnote)
                    .foregroundStyle(Theme.secondaryText)
            }
            .padding(20)
        }
        .safeAreaInset(edge: .bottom) {
            Group {
                if savedCount > 0 {
                    Button("Terminer", action: onFinish).buttonStyle(PrimaryButtonStyle())
                } else {
                    Button("Plus tard", action: onFinish).buttonStyle(SecondaryButtonStyle())
                }
            }
            .padding(20)
        }
    }

    // MARK: Review

    private var review: some View {
        let toCheck = drafts.filter(\.needsReview).count
        return ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(toCheck > 0 ? "\(Formatting.count(toCheck, "vêtement", "vêtements")) à vérifier" : "Tout est prêt")
                        .font(.system(.title3, design: .rounded).weight(.bold))
                        .foregroundStyle(Theme.ink)
                    Text("Touchez un vêtement pour corriger ce que Mino a reconnu.")
                        .font(.subheadline)
                        .foregroundStyle(Theme.secondaryText)
                }

                if drafts.contains(where: { $0.category.sizeKind == .clothing }) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Taille du lot")
                            .font(.system(.subheadline, design: .rounded).weight(.semibold))
                            .foregroundStyle(Theme.secondaryText)
                        ChipPicker(options: SizeChart.clothingSizes, selection: batchSize) {
                            SizeChart.shortLabel(size: $0, kind: .clothing)
                        }
                    }
                }

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 12)], spacing: 14) {
                    ForEach(drafts) { draft in
                        Button { editing = draft } label: { DraftTile(draft: draft) }
                            .buttonStyle(.plain)
                    }
                }

                if pendingAnalyses > 0 {
                    ProgressView("Encore \(pendingAnalyses) en cours d'analyse…")
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(20)
        }
        .safeAreaInset(edge: .bottom) {
            Button("Ajouter \(Formatting.count(drafts.count, "vêtement", "vêtements"))", action: saveAll)
                .buttonStyle(PrimaryButtonStyle())
                .padding(20)
                .background(.bar)
        }
    }

    /// The size shared by the batch: the most common clothing size, applied to every garment
    /// whose label was not read.
    private var batchSize: Binding<Int> {
        Binding(
            get: {
                let sizes = drafts.filter { $0.category.sizeKind == .clothing }.map(\.size)
                return Dictionary(grouping: sizes, by: { $0 }).max { $0.value.count < $1.value.count }?.key
                    ?? GarmentDraft.defaultSize(for: .clothing, sizing: sizing)
            },
            set: { size in
                for index in drafts.indices where drafts[index].category.sizeKind == .clothing && !drafts[index].sizeWasRead {
                    drafts[index].size = size
                }
            }
        )
    }

    // MARK: Actions

    private func importPhotos(_ items: [PhotosPickerItem]) async {
        pendingAnalyses += items.count
        for item in items {
            if let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data) {
                drafts.append(GarmentDraft(analysis: await GarmentAnalyzer.analyze(image), sizing: sizing))
            }
            pendingAnalyses -= 1
        }
    }

    private func analyze(_ image: UIImage) async {
        pendingAnalyses += 1
        drafts.append(GarmentDraft(analysis: await GarmentAnalyzer.analyze(image), sizing: sizing))
        pendingAnalyses -= 1
    }

    private func saveAll() {
        for draft in drafts {
            let garment = Garment(
                photo: draft.photo, category: draft.category, color: draft.color, size: draft.size,
                occasion: draft.occasion, brand: draft.brand.trimmingCharacters(in: .whitespaces),
                state: owner == nil ? .stored : .active
            )
            context.insert(garment)
            garment.owner = owner
        }
        savedCount += drafts.count
        drafts = []
    }
}

private struct DraftTile: View {
    let draft: GarmentDraft

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            GarmentImage(photo: draft.photo)
                .aspectRatio(1, contentMode: .fit)
                .overlay {
                    if draft.needsReview {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .strokeBorder(Theme.accent, lineWidth: 2.5)
                    }
                }
                .overlay(alignment: .topTrailing) {
                    if draft.needsReview {
                        Text("À vérifier")
                            .font(.caption2.weight(.bold))
                            .padding(.vertical, 3)
                            .padding(.horizontal, 7)
                            .foregroundStyle(Theme.onAccent)
                            .background(Theme.accent, in: Capsule())
                            .padding(6)
                    }
                }
            Text(draft.category.displayName)
                .font(.system(.caption, design: .rounded).weight(.semibold))
                .foregroundStyle(Theme.ink)
                .lineLimit(1)
            Text(SizeChart.shortLabel(size: draft.size, kind: draft.category.sizeKind))
                .font(.caption2)
                .foregroundStyle(Theme.secondaryText)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(draft.category.displayName), \(SizeChart.shortLabel(size: draft.size, kind: draft.category.sizeKind))\(draft.needsReview ? ", à vérifier" : "")")
    }
}

/// One garment of the batch, opened only when something needs fixing.
/// `onDone` receives the edited draft, or `nil` to remove it from the batch.
private struct DraftEditor: View {
    @State var draft: GarmentDraft
    let sizing: ChildProfile?
    let onDone: (GarmentDraft?) -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    GarmentImage(photo: draft.photo)
                        .frame(height: 220)
                    GarmentFields(
                        category: $draft.category, color: $draft.color, size: $draft.size,
                        occasion: $draft.occasion, brand: $draft.brand,
                        suggested: draft.suggestions, sizing: sizing
                    )
                    Button("Retirer du lot", role: .destructive) { onDone(nil) }
                }
                .padding(20)
            }
            .background(Theme.background)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("OK") {
                        draft.needsReview = false
                        onDone(draft)
                    }
                }
            }
        }
    }
}

private struct SourceCard: View {
    let symbol: String
    let title: String
    let message: String

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: symbol)
                .font(.title2)
                .foregroundStyle(Theme.onAccent)
                .frame(width: 52, height: 52)
                .background(Theme.accent, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(.headline, design: .rounded)).foregroundStyle(Theme.ink)
                Text(message).font(.subheadline).foregroundStyle(Theme.secondaryText)
            }
            Spacer()
            Image(systemName: "chevron.right").foregroundStyle(Theme.secondaryText)
        }
        .minoCard()
    }
}
