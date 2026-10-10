import Foundation

public enum Occasion: String, CaseIterable, Codable, Sendable {
    case everyday, dressy, sport

    public var displayName: String {
        switch self {
        case .everyday: return "Quotidien"
        case .dressy: return "Habillé"
        case .sport: return "Sport"
        }
    }
}

/// Where a garment is in its life.
public enum LifecycleState: String, CaseIterable, Codable, Sendable {
    /// In a child's wardrobe.
    case active
    /// In the family boxes, waiting for a younger child or the next season.
    case stored
    /// Listed for sale.
    case forSale
    case donated
    case sold
    /// Kept for its sentimental value.
    case keepsake

    /// Garments that left the family and found a second life elsewhere.
    public var hasLeftFamily: Bool { self == .donated || self == .sold }
}

/// A garment as the domain sees it: no photo, no persistence concerns.
public struct WardrobeItem: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let ownerID: UUID?
    public let category: GarmentCategory
    public let color: GarmentColor
    /// Centimetres for clothing, EU size for shoes (see `GarmentCategory.sizeKind`).
    public let size: Int
    public let occasion: Occasion
    public let state: LifecycleState
    public let lastWornAt: Date?
    /// Learned preference, from -2 (often swapped away) to 2 (often chosen).
    public let affinity: Double
    /// Child measurement (stature or shoe size) at which the parent confirmed it still fits.
    public let fitConfirmedAt: Double?

    public init(
        id: UUID = UUID(),
        ownerID: UUID?,
        category: GarmentCategory,
        color: GarmentColor,
        size: Int,
        occasion: Occasion = .everyday,
        state: LifecycleState = .active,
        lastWornAt: Date? = nil,
        affinity: Double = 0,
        fitConfirmedAt: Double? = nil
    ) {
        self.id = id
        self.ownerID = ownerID
        self.category = category
        self.color = color
        self.size = size
        self.occasion = occasion
        self.state = state
        self.lastWornAt = lastWornAt
        self.affinity = affinity
        self.fitConfirmedAt = fitConfirmedAt
    }
}
