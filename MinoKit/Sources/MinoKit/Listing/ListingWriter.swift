import Foundation

public struct Listing: Equatable, Sendable {
    public let title: String
    public let description: String

    /// Ready to paste into any resale app.
    public var text: String { "\(title)\n\n\(description)" }
}

/// Writes a factual resale listing. Mino never posts it: the parent shares it wherever they like.
public enum ListingWriter {
    public static func listing(for item: WardrobeItem, brand: String?) -> Listing {
        let kind = item.category.sizeKind
        let size = SizeChart.label(size: item.size, kind: kind)
        let brandName = brand.flatMap { $0.trimmingCharacters(in: .whitespaces).isEmpty ? nil : $0 }
        let title = [item.category.displayName + " enfant", SizeChart.shortLabel(size: item.size, kind: kind), brandName]
            .compactMap { $0 }
            .joined(separator: " · ")
        var lines = ["Taille : \(size)", "Couleur : \(item.color.displayName)"]
        if let brandName { lines.append("Marque : \(brandName)") }
        if item.occasion != .everyday { lines.append("Style : \(item.occasion.displayName.lowercased())") }
        lines.append("")
        lines.append("Il a fait son temps chez nous et attend une seconde vie.")
        return Listing(title: title, description: lines.joined(separator: "\n"))
    }

    /// One listing for several garments, as parents sell outgrown sizes: by the lot.
    public static func lot(of items: [WardrobeItem]) -> Listing {
        let clothingSizes = items.filter { $0.category.sizeKind == .clothing }.map(\.size).sorted()
        let sizeLabel: String?
        if let smallest = clothingSizes.first, let largest = clothingSizes.last {
            let low = SizeChart.shortLabel(size: smallest, kind: .clothing)
            let high = SizeChart.shortLabel(size: largest, kind: .clothing)
            sizeLabel = low == high ? low : "\(low) à \(high)"
        } else {
            sizeLabel = nil
        }
        let title = ["Lot de \(items.count) vêtements enfant", sizeLabel].compactMap { $0 }.joined(separator: " · ")
        let lines = items.map { item in
            "• \(item.category.displayName) \(item.color.displayName.lowercased()), \(SizeChart.shortLabel(size: item.size, kind: item.category.sizeKind))"
        }
        return Listing(
            title: title,
            description: (lines + ["", "Ils ont fait leur temps chez nous et attendent une seconde vie, ensemble."]).joined(separator: "\n")
        )
    }
}
