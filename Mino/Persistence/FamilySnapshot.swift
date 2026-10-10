import Foundation
import MinoKit

/// The whole family as the domain sees it, built once per render from SwiftData objects.
struct FamilySnapshot {
    let children: [Child]
    let profiles: [ChildProfile]
    let items: [WardrobeItem]
    private let garmentsByID: [UUID: Garment]

    init(children: [Child], garments: [Garment]) {
        self.children = children
        self.profiles = children.map(\.profile)
        self.items = garments.map(\.item)
        self.garmentsByID = Dictionary(garments.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    }

    func garment(_ id: UUID) -> Garment? { garmentsByID[id] }

    func child(_ id: UUID) -> Child? { children.first { $0.id == id } }

    func profile(_ id: UUID) -> ChildProfile? { profiles.first { $0.id == id } }

    func needs(on date: Date, calendar: Calendar) -> [Need] {
        let forecaster = NeedsForecaster(calendar: calendar)
        return profiles.flatMap { forecaster.needs(for: $0, family: profiles, items: items, on: date) }
    }
}
