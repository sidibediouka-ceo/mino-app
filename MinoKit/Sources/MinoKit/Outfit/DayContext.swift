import Foundation

/// What the child's day looks like; it changes what "the right outfit" means.
public enum DayContext: String, CaseIterable, Codable, Sendable {
    case school, sport, outing, celebration, home

    public var displayName: String {
        switch self {
        case .school: return "École"
        case .sport: return "Sport"
        case .outing: return "Sortie"
        case .celebration: return "Fête"
        case .home: return "Maison"
        }
    }

    /// The contexts worth offering: school, outing and home always change the outfit (coat,
    /// shoes); sport and celebration only once some garments are tagged for them.
    /// The current context is always kept, so a learned routine never disappears.
    public static func offered(for occasions: Set<Occasion>, current: DayContext) -> [DayContext] {
        allCases.filter { context in
            switch context {
            case .school, .outing, .home: return true
            case .sport: return occasions.contains(.sport) || context == current
            case .celebration: return occasions.contains(.dressy) || context == current
            }
        }
    }

    func occasionScore(_ occasion: Occasion) -> Double {
        switch (self, occasion) {
        case (.sport, .sport): return 1.5
        case (.sport, .dressy): return -2
        case (.celebration, .dressy): return 2
        case (.celebration, .sport): return -1.5
        case (.school, .dressy): return -1
        case (.outing, .dressy): return -0.3
        case (.home, .dressy): return -2
        case (.home, .sport): return 0.5
        default: return 0
        }
    }
}

/// The family's week, learned silently: when a parent picks "Sport" on a Wednesday,
/// Wednesdays become sport days until told otherwise.
public struct WeeklyRoutine: Equatable, Sendable {
    private var contexts: [Int: DayContext]

    /// Serialised as "4=sport;7=home" (keys are `Calendar` weekdays, 1 = Sunday).
    public init(rawValue: String) {
        var contexts: [Int: DayContext] = [:]
        for entry in rawValue.split(separator: ";") {
            let parts = entry.split(separator: "=")
            guard parts.count == 2, let weekday = Int(parts[0]), let context = DayContext(rawValue: String(parts[1])) else { continue }
            contexts[weekday] = context
        }
        self.contexts = contexts
    }

    public var rawValue: String {
        contexts.keys.sorted().compactMap { key in contexts[key].map { "\(key)=\($0.rawValue)" } }.joined(separator: ";")
    }

    public func context(on date: Date, calendar: Calendar) -> DayContext {
        let weekday = calendar.component(.weekday, from: date)
        if let learned = contexts[weekday] { return learned }
        return weekday == 1 || weekday == 7 ? .outing : .school
    }

    public func learning(_ context: DayContext, on date: Date, calendar: Calendar) -> WeeklyRoutine {
        var copy = self
        copy.contexts[calendar.component(.weekday, from: date)] = context
        return copy
    }
}
