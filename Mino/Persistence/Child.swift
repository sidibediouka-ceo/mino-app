import Foundation
import MinoKit
import SwiftData

/// Every property has a default and relationships are optional so the store can later sync
/// through CloudKit without a migration.
@Model
final class Child {
    var id: UUID = UUID()
    var name: String = ""
    var birthDate: Date = Date.now
    var sexRaw: String = Sex.unspecified.rawValue
    var createdAt: Date = Date.now
    /// The learned weekly routine, see `WeeklyRoutine`.
    var routineRaw: String = ""

    @Relationship(deleteRule: .cascade, inverse: \GrowthEntry.child)
    var growthEntries: [GrowthEntry]? = []

    @Relationship(deleteRule: .nullify, inverse: \Garment.owner)
    var garments: [Garment]? = []

    @Relationship(deleteRule: .cascade, inverse: \PlannedOutfit.child)
    var plans: [PlannedOutfit]? = []

    init(name: String, birthDate: Date, sex: Sex) {
        self.name = name
        self.birthDate = birthDate
        self.sexRaw = sex.rawValue
    }

    var sex: Sex {
        get { Sex(rawValue: sexRaw) ?? .unspecified }
        set { sexRaw = newValue.rawValue }
    }

    var routine: WeeklyRoutine {
        get { WeeklyRoutine(rawValue: routineRaw) }
        set { routineRaw = newValue.rawValue }
    }

    var profile: ChildProfile {
        ChildProfile(id: id, name: name, birthDate: birthDate, sex: sex, records: (growthEntries ?? []).map(\.record))
    }
}

@Model
final class GrowthEntry {
    var date: Date = Date.now
    var heightCM: Double?
    var shoeSize: Double?
    var isApproximate: Bool = false
    var child: Child?

    init(date: Date, heightCM: Double?, shoeSize: Double?, isApproximate: Bool) {
        self.date = date
        self.heightCM = heightCM
        self.shoeSize = shoeSize
        self.isApproximate = isApproximate
    }

    var record: GrowthRecord {
        GrowthRecord(date: date, heightCM: heightCM, shoeSize: shoeSize, isApproximate: isApproximate)
    }
}
