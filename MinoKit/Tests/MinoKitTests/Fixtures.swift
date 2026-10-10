import Foundation
@testable import MinoKit

enum Fixtures {
    static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Paris")!
        return calendar
    }()

    static func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    static let today = date(2026, 10, 10)

    /// A four-year-old boy measured at 104 cm today and wearing shoe size 27.
    static let leo = ChildProfile(
        id: UUID(), name: "Léo", estimatedBirth: date(2022, 10, 10),
        records: [GrowthRecord(date: today, heightCM: 104, shoeSize: 27)]
    )

    /// His little sister, two years old, 86 cm.
    static let ines = ChildProfile(
        id: UUID(), name: "Inès", estimatedBirth: date(2024, 9, 1),
        records: [GrowthRecord(date: today, heightCM: 86, shoeSize: 22)]
    )

    static func item(
        _ category: GarmentCategory, owner: ChildProfile? = leo, size: Int? = nil, color: GarmentColor = .navy,
        occasion: Occasion = .everyday, state: LifecycleState = .active, lastWornAt: Date? = nil
    ) -> WardrobeItem {
        WardrobeItem(
            ownerID: owner?.id, category: category, color: color,
            size: size ?? (category.sizeKind == .shoes ? 28 : 110),
            occasion: occasion, state: state, lastWornAt: lastWornAt
        )
    }

    static func weather(morning: Double, high: Double, rain: Double = 0, on date: Date = today) -> DayForecast {
        DayForecast(date: date, morningC: morning, highC: high, precipitationChance: rain, condition: rain >= 0.5 ? .rain : .clear)
    }
}
