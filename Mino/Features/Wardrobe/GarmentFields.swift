import MinoKit
import SwiftUI

/// The garment editor shared by the add flow and the detail screen: chips everywhere, typing only for the brand.
struct GarmentFields: View {
    @Binding var category: GarmentCategory
    @Binding var color: GarmentColor
    @Binding var size: Int
    @Binding var occasion: Occasion
    @Binding var brand: String
    /// The child sizes are suggested and checked against.
    let sizing: ChildProfile?

    @State private var scanningLabel = false
    @State private var labelMessage: String?

    private var kind: SizeKind { category.sizeKind }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            field("Catégorie") {
                ChipPicker(options: GarmentCategory.allCases, selection: $category, title: \.displayName)
            }
            field("Couleur") {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(GarmentColor.allCases, id: \.self) { option in
                            Button { color = option } label: {
                                ColorSwatch(color: option, size: 34)
                                    .padding(3)
                                    .overlay(Circle().strokeBorder(Theme.forest, lineWidth: option == color ? 2 : 0))
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
                        Text(labelMessage).font(.footnote).foregroundStyle(Theme.forest)
                    }
                }
            }
            field("Occasion") {
                ChipPicker(options: Occasion.allCases, selection: $occasion, title: \.displayName)
            }
            field("Marque (facultatif)") {
                TextField("Ex. Petit Bateau", text: $brand)
                    .textFieldStyle(.roundedBorder)
            }
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
                .font(.subheadline.weight(.semibold))
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
        case .tooSmall: return "Trop petit pour \(child.name)"
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

    init(analysis: GarmentAnalysis, sizing: ChildProfile?) {
        let category = analysis.category ?? .tshirt
        self.photo = analysis.photo
        self.category = category
        self.color = analysis.color ?? .white
        self.size = SizeLabelParser.size(in: analysis.texts, kind: category.sizeKind)
            ?? Self.defaultSize(for: category.sizeKind, sizing: sizing)
    }

    /// Most garments a parent photographs fit the child today.
    static func defaultSize(for kind: SizeKind, sizing: ChildProfile?) -> Int {
        if let sizing { return sizing.currentSize(kind, on: .now) }
        return kind == .clothing ? 104 : 27
    }
}
