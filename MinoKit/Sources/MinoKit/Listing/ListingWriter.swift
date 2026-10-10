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
}
