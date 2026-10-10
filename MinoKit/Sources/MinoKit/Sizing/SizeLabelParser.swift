import Foundation

/// Reads a size from the text recognised on a garment's care label.
///
/// Handles centimetre labels ("104", "110/116 cm", Japanese "120"), French and English age
/// labels ("4 ans", "3-4Y", "18 mois", "12-18M") and EU shoe sizes ("27", "EU 28", "P29").
public enum SizeLabelParser {
    public static func size(in texts: [String], kind: SizeKind) -> Int? {
        let text = texts.joined(separator: " | ").lowercased()
        switch kind {
        case .clothing: return clothingSize(in: text)
        case .shoes: return shoeSize(in: text)
        }
    }

    private static func clothingSize(in text: String) -> Int? {
        if let cm = upperBound(in: text, pattern: #"(\d{2,3})\s*(?:[-/]\s*(\d{2,3}))?\s*cm"#),
           (45...176).contains(cm) {
            return SizeChart.snapClothing(Double(cm))
        }
        if let years = upperBound(in: text, pattern: #"\b(\d{1,2})\s*(?:[-/à]\s*(\d{1,2}))?\s*(?:ans|an|years|year|yrs|y|a)\b"#),
           (1...16).contains(years) {
            return SizeChart.clothingSize(forAgeInMonths: years * 12)
        }
        if let months = upperBound(in: text, pattern: #"\b(\d{1,2})\s*(?:[-/]\s*(\d{1,2}))?\s*(?:mois|months|month|mths|m)\b"#),
           (0...36).contains(months) {
            return SizeChart.clothingSize(forAgeInMonths: months)
        }
        if let bare = upperBound(in: text, pattern: #"\b(\d{2,3})(?:\s*/\s*(\d{2,3}))?\b(?!\s*[%°])"#),
           (50...176).contains(bare) {
            return SizeChart.snapClothing(Double(bare))
        }
        return nil
    }

    private static func shoeSize(in text: String) -> Int? {
        let prefixed = #"(?:eu|eur|pointure|p\.?)\s*(\d{2})\b"#
        let bare = #"\b(\d{2})\b(?!\s*[%°])"#
        for pattern in [prefixed, bare] {
            if let size = upperBound(in: text, pattern: pattern), SizeChart.shoeSizes.contains(size) {
                return size
            }
        }
        return nil
    }

    /// First match of `pattern`; returns its second group when present (upper bound of a range), else its first.
    private static func upperBound(in text: String, pattern: String) -> Int? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, range: range) else { return nil }
        for group in stride(from: match.numberOfRanges - 1, through: 1, by: -1) {
            if let groupRange = Range(match.range(at: group), in: text), let value = Int(text[groupRange]) {
                return value
            }
        }
        return nil
    }
}
