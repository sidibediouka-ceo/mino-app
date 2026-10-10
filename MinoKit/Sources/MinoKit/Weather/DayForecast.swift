import Foundation

public enum SkyCondition: String, Sendable {
    case clear, cloudy, rain, snow
}

/// How a day feels for a child who leaves home in the morning and plays outside at noon.
public enum Thermal: Int, Comparable, Sendable {
    case freezing, cold, cool, mild, warm, hot

    public static func < (lhs: Thermal, rhs: Thermal) -> Bool { lhs.rawValue < rhs.rawValue }

    init(dressingTemperature t: Double) {
        switch t {
        case ..<5: self = .freezing
        case ..<11: self = .cold
        case ..<16: self = .cool
        case ..<22: self = .mild
        case ..<27: self = .warm
        default: self = .hot
        }
    }
}

public struct DayForecast: Equatable, Sendable {
    public let date: Date
    /// Apparent temperature around 8 am.
    public let morningC: Double
    public let highC: Double
    /// 0…1
    public let precipitationChance: Double
    public let condition: SkyCondition
    /// True when this is a seasonal estimate because no forecast was available.
    public let isEstimate: Bool

    public init(
        date: Date, morningC: Double, highC: Double,
        precipitationChance: Double, condition: SkyCondition, isEstimate: Bool = false
    ) {
        self.date = date
        self.morningC = morningC
        self.highC = highC
        self.precipitationChance = precipitationChance
        self.condition = condition
        self.isEstimate = isEstimate
    }

    public var isRainy: Bool { condition == .rain || precipitationChance >= 0.4 }

    /// Weighted towards the morning, when the child gets dressed and goes out.
    var dressingTemperature: Double { morningC * 0.6 + highC * 0.4 }

    public var thermal: Thermal { Thermal(dressingTemperature: dressingTemperature) }

    /// Typical weather in temperate western Europe, used when no forecast is available.
    public static func seasonalEstimate(for date: Date, calendar: Calendar) -> DayForecast {
        let normals: [(low: Double, high: Double)] = [
            (3, 7), (3, 8), (5, 12), (7, 16), (11, 20), (14, 23),
            (16, 25), (16, 25), (13, 21), (10, 16), (6, 11), (4, 8)
        ]
        let normal = normals[calendar.component(.month, from: date) - 1]
        return DayForecast(
            date: date, morningC: normal.low + 1, highC: normal.high,
            precipitationChance: 0.3, condition: .cloudy, isEstimate: true
        )
    }
}
