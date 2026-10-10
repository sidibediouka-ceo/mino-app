import Foundation
import MinoKit

/// French phrasing for dates, windows and lists. Mino speaks like a person, not a database.
enum Formatting {
    private static let locale = Locale(identifier: "fr_FR")

    private static let monthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.dateFormat = "LLLL"
        return formatter
    }()

    private static let shortFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.setLocalizedDateFormatFromTemplate("d MMM")
        return formatter
    }()

    private static let longFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.setLocalizedDateFormatFromTemplate("EEEE d MMMM")
        return formatter
    }()

    /// "mi-février", "début mars", "fin janvier 2028".
    static func period(_ date: Date, calendar: Calendar = .current) -> String {
        let day = calendar.component(.day, from: date)
        let month = monthFormatter.string(from: date)
        var text: String
        switch day {
        case ...10: text = "début \(month)"
        case ...20: text = "mi-\(month)"
        default: text = "fin \(month)"
        }
        if calendar.component(.year, from: date) != calendar.component(.year, from: .now) {
            text += " \(calendar.component(.year, from: date))"
        }
        return text
    }

    /// "vers mi-février (entre janvier et mars)", honest about uncertainty.
    static func window(_ estimate: DateEstimate, calendar: Calendar = .current) -> String {
        let expected = "vers \(period(estimate.expected, calendar: calendar))"
        let first = monthFormatter.string(from: estimate.earliest)
        let last = monthFormatter.string(from: estimate.latest)
        return first == last ? expected : "\(expected) (entre \(first) et \(last))"
    }

    static func shortDate(_ date: Date) -> String {
        shortFormatter.string(from: date)
    }

    static func longDate(_ date: Date) -> String {
        sentence(longFormatter.string(from: date))
    }

    /// Capitalises the first letter only, as French sentences and dates expect.
    static func sentence(_ text: String) -> String {
        text.prefix(1).uppercased() + text.dropFirst()
    }

    /// "Léo", "Léo et Inès", "Léo, Inès et Jules".
    static func names(_ names: [String]) -> String {
        guard let last = names.last else { return "" }
        return names.count == 1 ? last : names.dropLast().joined(separator: ", ") + " et " + last
    }

    /// "8° → 14° · pluie 60 %"
    static func forecast(_ forecast: DayForecast) -> String {
        var text = "\(Int(forecast.morningC.rounded()))° → \(Int(forecast.highC.rounded()))°"
        if forecast.isRainy {
            text += " · pluie \(Int((forecast.precipitationChance * 100).rounded())) %"
        }
        return text
    }

    static func symbol(for forecast: DayForecast) -> String {
        switch forecast.condition {
        case .clear: return "sun.max.fill"
        case .cloudy: return "cloud.sun.fill"
        case .rain: return "cloud.rain.fill"
        case .snow: return "cloud.snow.fill"
        }
    }

    /// "1 vêtement", "3 vêtements".
    static func count(_ value: Int, _ singular: String, _ plural: String) -> String {
        "\(value) \(value > 1 ? plural : singular)"
    }

    /// "Octobre 2026".
    static func month(_ date: Date) -> String {
        sentence("\(monthFormatter.string(from: date)) \(Calendar.current.component(.year, from: date))")
    }

    /// "Moins d'un mois", "18 mois", "4 ans".
    static func age(months: Int) -> String {
        switch months {
        case ..<1: return "Moins d'un mois"
        case ..<24: return "\(months) mois"
        default: return "\(months / 12) ans"
        }
    }
}
