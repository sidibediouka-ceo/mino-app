import Foundation

public enum Fit: Equatable, Sendable {
    case tooBig, roomy, fits, tooSmall

    public var isWearable: Bool { self == .fits || self == .roomy }
}

extension ChildProfile {
    /// The child measurement the item's size is compared against.
    public func measurement(for kind: SizeKind, at date: Date) -> Estimate {
        switch kind {
        case .clothing: return height(at: date)
        case .shoes: return shoeSize(at: date)
        }
    }

    /// Whether `item` will fit the child on `date`.
    ///
    /// Clothing labelled `s` cm fits statures in (s − 8, s + 2]; between s − 14 and s − 8 it is
    /// roomy but wearable. Shoes labelled `s` fit an estimated size in (s − 1.2, s + 0.3] and are roomy down to s − 2.5.
    /// A parent's "still fits" pushes the upper bound a little further.
    public func fit(of item: WardrobeItem, on date: Date) -> Fit {
        let size = Double(item.size)
        let current = measurement(for: item.category.sizeKind, at: date).expected
        let bounds: (tooSmallAbove: Double, fitsAbove: Double, roomyAbove: Double, confirmedMargin: Double)
        switch item.category.sizeKind {
        case .clothing: bounds = (size + 2, size - 8, size - 14, 3)
        case .shoes: bounds = (size + 0.3, size - 1.2, size - 2.5, 0.5)
        }
        let upper = max(bounds.tooSmallAbove, (item.fitConfirmedAt ?? -.infinity) + bounds.confirmedMargin)
        if current > upper { return .tooSmall }
        if current > bounds.fitsAbove { return .fits }
        if current > bounds.roomyAbove { return .roomy }
        return .tooBig
    }

    /// When a garment that is still too big will start to fit properly.
    public func dateItemFits(_ item: WardrobeItem, from date: Date) -> DateEstimate? {
        let size = Double(item.size)
        switch item.category.sizeKind {
        case .clothing: return dateReaching(heightCM: size - 8 + 0.01, from: date)
        case .shoes: return dateReaching(shoeSize: size - 1.2 + 0.01, from: date)
        }
    }
}
