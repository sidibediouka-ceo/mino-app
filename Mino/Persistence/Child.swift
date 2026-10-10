import Foundation
import MinoKit
import SwiftData

/// Every property has a default and relationships are optional so the store can later sync
/// through CloudKit without a migration.
@Model
final class Child {
    var id: UUID = UUID()
    var name: String = ""
    /// The age the parent gave, and when. Mino never asks for a date of birth.
    var ageInMonthsAtEntry: Int = 0
    var ageEnteredAt: Date = Date.now
    var createdAt: Date = Date.now
    /// The learned weekly routine, see `WeeklyRoutine`.
    var routineRaw: String = ""

    @Relationship(deleteRule: .cascade, inverse: \GrowthEntry.child)
    var growthEntries: [GrowthEntry]? = []

    @Relationship(deleteRule: .nullify, inverse: \Garment.owner)
    var garments: [Garment]? = []

    @Relationship(deleteRule: .cascade, inverse: \PlannedOutfit.child)
    var plans: [PlannedOutfit]? = []

    init(name: String, ageInMonths: Int) {
        self.name = name
        self.ageInMonthsAtEntry = ageInMonths
    }

    /// Today's age, kept up to date from the age given at entry.
    var ageInMonths: Int {
        get { Int(profile.ageInMonths(at: .now)) }
        set {
            ageInMonthsAtEntry = newValue
            ageEnteredAt = .now
        }
    }

    var routine: WeeklyRoutine {
        get { WeeklyRoutine(rawValue: routineRaw) }
        set { routineRaw = newValue.rawValue }
    }

    var profile: ChildProfile {
        ChildProfile(
            id: id, name: name,
            estimatedBirth: ChildProfile.estimatedBirth(ageInMonths: ageInMonthsAtEntry, on: ageEnteredAt),
            records: (growthEntries ?? []).map(\.record)
        )
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
