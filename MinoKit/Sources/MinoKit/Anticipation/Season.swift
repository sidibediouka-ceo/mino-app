import Foundation

/// Meteorological seasons (northern hemisphere).
public enum Season: String, CaseIterable, Sendable {
    case winter, spring, summer, autumn

    public var displayName: String {
        switch self {
        case .winter: return "l'hiver"
        case .spring: return "le printemps"
        case .summer: return "l'été"
        case .autumn: return "l'automne"
        }
    }

    private var startMonth: Int {
        switch self {
        case .winter: return 12
        case .spring: return 3
        case .summer: return 6
        case .autumn: return 9
        }
    }

    public static func of(_ date: Date, calendar: Calendar) -> Season {
        switch calendar.component(.month, from: date) {
        case 3...5: return .spring
        case 6...8: return .summer
        case 9...11: return .autumn
        default: return .winter
        }
    }

    var next: Season {
        switch self {
        case .winter: return .spring
        case .spring: return .summer
        case .summer: return .autumn
        case .autumn: return .winter
        }
    }

    /// First day of the next occurrence of this season strictly after `date`.
    func nextStart(after date: Date, calendar: Calendar) -> Date {
        let components = DateComponents(month: startMonth, day: 1)
        return calendar.nextDate(after: date, matching: components, matchingPolicy: .nextTime) ?? date
    }
}

/// Groups of garments a parent counts together when asking "does she have enough?".
public enum NeedGroup: String, CaseIterable, Sendable {
    case shortSleeveTops, longSleeveTops, layers, longBottoms, summerBottoms
    case warmOuterwear, rainOuterwear, everydayShoes, warmShoes, summerShoes, pajamas

    public var displayName: String {
        switch self {
        case .shortSleeveTops: return "T-shirts"
        case .longSleeveTops: return "Hauts manches longues"
        case .layers: return "Pulls & gilets"
        case .longBottoms: return "Pantalons"
        case .summerBottoms: return "Shorts, jupes & robes"
        case .warmOuterwear: return "Manteau"
        case .rainOuterwear: return "Veste de pluie"
        case .everydayShoes: return "Baskets"
        case .warmShoes: return "Bottes"
        case .summerShoes: return "Sandales"
        case .pajamas: return "Pyjamas"
        }
    }

    var categories: Set<GarmentCategory> {
        switch self {
        case .shortSleeveTops: return [.tshirt]
        case .longSleeveTops: return [.longSleeve, .turtleneck]
        case .layers: return [.sweater, .cardigan]
        case .longBottoms: return [.pants, .overalls]
        case .summerBottoms: return [.shorts, .dress, .playsuit]
        case .warmOuterwear: return [.coat]
        case .rainOuterwear: return [.raincoat, .lightJacket]
        case .everydayShoes: return [.sneakers]
        case .warmShoes: return [.boots]
        case .summerShoes: return [.sandals]
        case .pajamas: return [.pajamas]
        }
    }

    public var sizeKind: SizeKind {
        switch self {
        case .everydayShoes, .warmShoes, .summerShoes: return .shoes
        default: return .clothing
        }
    }

    /// A school-week capsule with one wash a week: enough, not more.
    func target(in season: Season) -> Int {
        switch (self, season) {
        case (.longSleeveTops, .winter): return 6
        case (.longSleeveTops, .spring), (.longSleeveTops, .autumn): return 5
        case (.shortSleeveTops, .summer): return 6
        case (.shortSleeveTops, .spring), (.shortSleeveTops, .autumn): return 3
        case (.layers, .winter): return 3
        case (.layers, .spring), (.layers, .autumn): return 2
        case (.longBottoms, .winter), (.longBottoms, .spring), (.longBottoms, .autumn): return 5
        case (.summerBottoms, .summer): return 5
        case (.warmOuterwear, .winter): return 1
        case (.rainOuterwear, .spring), (.rainOuterwear, .autumn): return 1
        case (.everydayShoes, _): return 1
        case (.warmShoes, .winter): return 1
        case (.summerShoes, .summer): return 1
        case (.pajamas, .summer): return 3
        case (.pajamas, _): return 4
        default: return 0
        }
    }
}
