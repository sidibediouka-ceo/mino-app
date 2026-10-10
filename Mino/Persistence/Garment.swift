import Foundation
import MinoKit
import SwiftData

@Model
final class Garment {
    var id: UUID = UUID()
    var createdAt: Date = Date.now
    var categoryRaw: String = GarmentCategory.tshirt.rawValue
    var colorRaw: String = GarmentColor.white.rawValue
    /// Centimetres for clothing, EU size for shoes.
    var size: Int = 104
    var occasionRaw: String = Occasion.everyday.rawValue
    var stateRaw: String = LifecycleState.active.rawValue
    var brand: String = ""
    /// Background-free photo (PNG), kept on device.
    @Attribute(.externalStorage) var photo: Data?
    var lastWornAt: Date?
    var wearCount: Int = 0
    var affinity: Double = 0
    var fitConfirmedAt: Double?
    var owner: Child?
    /// The child who wore it last, kept when it moves to the boxes, a sibling or a second life.
    var lastOwnerID: UUID?
    /// Set when the garment is put up for sale.
    var conditionRaw: String?

    init(
        photo: Data?, category: GarmentCategory, color: GarmentColor, size: Int,
        occasion: Occasion, brand: String, state: LifecycleState
    ) {
        self.photo = photo
        self.categoryRaw = category.rawValue
        self.colorRaw = color.rawValue
        self.size = size
        self.occasionRaw = occasion.rawValue
        self.brand = brand
        self.stateRaw = state.rawValue
    }

    var category: GarmentCategory {
        get { GarmentCategory(rawValue: categoryRaw) ?? .tshirt }
        set { categoryRaw = newValue.rawValue }
    }

    var color: GarmentColor {
        get { GarmentColor(rawValue: colorRaw) ?? .white }
        set { colorRaw = newValue.rawValue }
    }

    var occasion: Occasion {
        get { Occasion(rawValue: occasionRaw) ?? .everyday }
        set { occasionRaw = newValue.rawValue }
    }

    var state: LifecycleState {
        get { LifecycleState(rawValue: stateRaw) ?? .active }
        set { stateRaw = newValue.rawValue }
    }

    var condition: Condition? {
        get { conditionRaw.flatMap(Condition.init(rawValue:)) }
        set { conditionRaw = newValue?.rawValue }
    }

    var item: WardrobeItem {
        WardrobeItem(
            id: id, ownerID: owner?.id, category: category, color: color, size: size,
            occasion: occasion, state: state, lastWornAt: lastWornAt, affinity: affinity,
            fitConfirmedAt: fitConfirmedAt, condition: condition
        )
    }

    /// "Pantalon marine · 4 ans", for VoiceOver and confirmations.
    var summary: String {
        "\(category.displayName) \(color.displayName.lowercased()) · \(SizeChart.shortLabel(size: size, kind: category.sizeKind))"
    }

    /// Moves the garment to a new place in its life, remembering whose it was.
    func move(to state: LifecycleState, owner: Child?) {
        if let previous = self.owner, previous.id != owner?.id {
            lastOwnerID = previous.id
        }
        self.state = state
        self.owner = owner
        fitConfirmedAt = nil
    }

    /// Applies a lifecycle recommendation (or a parent's choice among them).
    func apply(_ destination: Destination, children: [Child]) {
        switch destination {
        case .sibling(let childID, _):
            move(to: .active, owner: children.first { $0.id == childID })
        case .store:
            move(to: .stored, owner: nil)
        case .donate:
            move(to: .donated, owner: nil)
        case .sell:
            move(to: .forSale, owner: nil)
        }
    }
}
