import MinoKit
import SwiftUI

/// The garment editor shared by the add flow and the detail screen. Mino's guesses come first,
/// rarely needed details are folded away, and only the brand is ever typed.
struct GarmentFields: View {
    @Binding var category: GarmentCategory
    @Binding var color: GarmentColor
    @Binding var size: Int
    @Binding var occasion: Occasion
    @Binding var brand: String
    /// Categories Mino recognised, most likely first; they lead the list.
    let suggested: [GarmentCategory]
    /// The child sizes are suggested and checked against.
    let sizing: ChildProfile?

    @State private var scanningLabel = false
    @State private var labelMessage: String?

    private var kind: SizeKind { category.sizeKind }

    /// Bodies only show up for babies; the chosen category always stays listed.
    private var categoryOptions: [GarmentCategory] {
        let childSize = sizing?.currentSize(.clothing, on: .now) ?? size
        return (suggested + GarmentCategory.allCases.filter { !suggested.contains($0) })
            .filter { $0 == category || $0.isOffered(forClothingSize: childSize) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            field("Catégorie") {
                ChipPicker(options: categoryOptions, selection: $category, title: \.displayName)
            }
            field("Couleur") {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(GarmentColor.allCases, id: \.self) { option in
                            Button { color = option } label: {
                                ColorSwatch(color: option, size: 34)
                                    .padding(3)
                                    .overlay(Circle().strokeBorder(Theme.ink, lineWidth: option == color ? 2 : 0))
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(option.displayName)
                            .accessibilityAddTraits(option == color ? .isSelected : [])
                        }
                    }
                }
            }
            field("Taille") {
                VStack(alignment: .leading, spacing: 10) {
                    ChipPicker(options: kind == .clothing ? SizeChart.clothingSizes : SizeChart.shoeSizes, selection: $size) {
                        SizeChart.shortLabel(size: $0, kind: kind)
                    }
                    HStack {
                        if let sizing {
                            Text(fitHint(for: sizing))
                                .font(.footnote)
                                .foregroundStyle(Theme.secondaryText)
                        }
                        Spacer()
                        if CameraPicker.isAvailable {
                            Button("Lire l'étiquette", systemImage: "text.viewfinder") { scanningLabel = true }
                                .buttonStyle(SecondaryButtonStyle())
                        }
                    }
                    if let labelMessage {
                        Text(labelMessage).font(.footnote).foregroundStyle(Theme.ink)
                    }
                }
            }
            field("Pour quelles journées ?") {
                ChipPicker(options: Occasion.allCases, selection: $occasion, title: \.displayName)
            }
            DisclosureGroup("Plus de détails") {
                field("Marque") {
                    TextField("Ex. Petit Bateau", text: $brand)
                        .textFieldStyle(.roundedBorder)
                }
                .padding(.top, 12)
            }
            .tint(Theme.ink)
        }
        .onChange(of: category) { oldValue, newValue in
            if oldValue.sizeKind != newValue.sizeKind {
                size = GarmentDraft.defaultSize(for: newValue.sizeKind, sizing: sizing)
            }
        }
        .fullScreenCover(isPresented: $scanningLabel) {
            CameraPicker { image in
                Task { await readLabel(image) }
            }
            .ignoresSafeArea()
        }
    }

    private func field<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                .foregroundStyle(Theme.secondaryText)
            content()
        }
    }

    private func fitHint(for child: ChildProfile) -> String {
        let item = WardrobeItem(ownerID: child.id, category: category, color: color, size: size)
        switch child.fit(of: item, on: .now) {
        case .fits: return "À la taille de \(child.name)"
        case .roomy: return "Un peu grand pour \(child.name)"
        case .tooBig: return "Pour plus tard"
        case .tooSmall: return "Déjà petit pour \(child.name)"
        }
    }

    private func readLabel(_ image: UIImage) async {
        let texts = await GarmentAnalyzer.readLabel(image)
        if let parsed = SizeLabelParser.size(in: texts, kind: kind) {
            size = parsed
            labelMessage = "Étiquette lue : \(SizeChart.label(size: parsed, kind: kind))"
        } else {
            labelMessage = "Étiquette illisible : choisissez la taille ci-dessus."
        }
    }
}

/// A garment being added, pre-filled from the photo analysis.
struct GarmentDraft: Identifiable {
    let id = UUID()
    var photo: Data
    var category: GarmentCategory
    var color: GarmentColor
    var size: Int
    var occasion: Occasion = .everyday
    var brand = ""
    /// Recognised categories, most likely first.
    let suggestions: [GarmentCategory]
    /// The size came from the care label, so batch-wide size changes leave it alone.
    let sizeWasRead: Bool
    /// Mino could not tell what it is: the parent should have a look.
    var needsReview: Bool

    init(analysis: GarmentAnalysis, sizing: ChildProfile?) {
        // A guessed body is no use for a child who has outgrown them.
        let childSize = sizing?.currentSize(.clothing, on: .now)
        let categories = analysis.categories.filter { category in childSize.map(category.isOffered(forClothingSize:)) ?? true }
        let category = categories.first ?? .tshirt
        let readSize = SizeLabelParser.size(in: analysis.texts, kind: category.sizeKind)
        self.photo = analysis.photo
        self.category = category
        self.color = analysis.color ?? .white
        self.size = readSize ?? Self.defaultSize(for: category.sizeKind, sizing: sizing)
        self.suggestions = Array(categories.prefix(3))
        self.sizeWasRead = readSize != nil
        // Guessed from the outline alone: right most of the time, but worth a look.
        self.needsReview = categories.isEmpty || !analysis.isRecognized
    }

    /// Most garments a parent photographs fit the child today.
    static func defaultSize(for kind: SizeKind, sizing: ChildProfile?) -> Int {
        if let sizing { return sizing.currentSize(kind, on: .now) }
        return kind == .clothing ? 104 : 27
    }
}
