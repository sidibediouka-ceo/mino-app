import MinoKit
import PhotosUI
import SwiftData
import SwiftUI

/// Batch digitisation: pick up to 20 photos (or shoot them one after another), Mino lifts the
/// garment off the background and pre-fills everything; the parent only confirms.
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
    }

    // MARK: Sources

    private var sources: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if savedCount > 0 {
                    Label("\(Formatting.count(savedCount, "vêtement ajouté", "vêtements ajoutés"))", systemImage: "checkmark.circle.fill")
                        .font(.headline)
                        .foregroundStyle(Theme.forest)
                } else {
                    Text("Une dizaine de photos suffit pour commencer. Mino détoure, reconnaît la catégorie, la couleur et, si l'étiquette est visible, la taille.")
                        .foregroundStyle(Theme.secondaryText)
                }

                PhotosPicker(selection: $pickerItems, maxSelectionCount: 20, matching: .images) {
                    SourceCard(symbol: "photo.on.rectangle.angled", title: "Choisir dans la photothèque", message: "Jusqu'à 20 photos d'un coup")
                }
                .buttonStyle(.plain)

                if CameraPicker.isAvailable {
                    Button { showingCamera = true } label: {
                        SourceCard(symbol: "camera", title: "Prendre en photo", message: "Une photo après l'autre, en rafale")
                    }
                    .buttonStyle(.plain)
                }

                Label("Posé à plat sur un fond uni, le vêtement est détouré parfaitement.", systemImage: "lightbulb")
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
        DraftReview(draft: drafts[0], sizing: sizing, progress: reviewProgress) { confirmed in
            drafts.removeFirst()
            if let confirmed { save(confirmed) }
        }
        .id(drafts[0].id)
    }

    private var reviewProgress: String {
        let remaining = drafts.count - 1
        var text = remaining > 0 ? "Encore \(remaining) après celui-ci" : "Dernier à valider"
        if pendingAnalyses > 0 { text += " · \(pendingAnalyses) en cours d'analyse" }
        return text
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

    private func save(_ draft: GarmentDraft) {
        let garment = Garment(
            photo: draft.photo, category: draft.category, color: draft.color, size: draft.size,
            occasion: draft.occasion, brand: draft.brand.trimmingCharacters(in: .whitespaces),
            state: owner == nil ? .stored : .active
        )
        context.insert(garment)
        garment.owner = owner
        savedCount += 1
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
                .foregroundStyle(Theme.forest)
                .frame(width: 48, height: 48)
                .background(Theme.sage.opacity(0.2), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline).foregroundStyle(Theme.forest)
                Text(message).font(.subheadline).foregroundStyle(Theme.secondaryText)
            }
            Spacer()
            Image(systemName: "chevron.right").foregroundStyle(Theme.secondaryText)
        }
        .minoCard()
    }
}

/// One pre-filled garment to confirm. `onDecision` receives the edited draft, or `nil` when skipped.
private struct DraftReview: View {
    @State var draft: GarmentDraft
    let sizing: ChildProfile?
    let progress: String
    let onDecision: (GarmentDraft?) -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                GarmentImage(photo: draft.photo)
                    .frame(height: 240)
                GarmentFields(
                    category: $draft.category, color: $draft.color, size: $draft.size,
                    occasion: $draft.occasion, brand: $draft.brand, sizing: sizing
                )
            }
            .padding(20)
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 8) {
                Text(progress)
                    .font(.footnote)
                    .foregroundStyle(Theme.secondaryText)
                HStack(spacing: 12) {
                    Button("Ignorer") { onDecision(nil) }
                        .buttonStyle(SecondaryButtonStyle())
                    Button("Ajouter") { onDecision(draft) }
                        .buttonStyle(PrimaryButtonStyle())
                }
            }
            .padding(20)
            .background(.bar)
        }
    }
}
