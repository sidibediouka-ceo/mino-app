import Foundation

public enum Sex: String, CaseIterable, Codable, Sendable {
    case girl, boy, unspecified
}

/// Reference curves derived from the WHO Child Growth Standards (0–5 years) and the
/// WHO 2007 growth reference (5–16 years). Values are rounded; Mino is not a medical tool.
enum GrowthReference {
    private struct Point {
        let months: Double
        let boy: Double
        let girl: Double
        let standardDeviation: Double
    }

    private static let stature: [Point] = [
        Point(months: 0, boy: 49.9, girl: 49.1, standardDeviation: 1.9),
        Point(months: 3, boy: 61.4, girl: 59.8, standardDeviation: 2.1),
        Point(months: 6, boy: 67.6, girl: 65.7, standardDeviation: 2.3),
        Point(months: 9, boy: 72.0, girl: 70.1, standardDeviation: 2.5),
        Point(months: 12, boy: 75.7, girl: 74.0, standardDeviation: 2.6),
        Point(months: 18, boy: 82.3, girl: 80.7, standardDeviation: 2.9),
        Point(months: 24, boy: 86.8, girl: 85.4, standardDeviation: 3.1),
        Point(months: 36, boy: 96.1, girl: 95.1, standardDeviation: 3.7),
        Point(months: 48, boy: 103.3, girl: 102.7, standardDeviation: 4.2),
        Point(months: 60, boy: 110.0, girl: 109.4, standardDeviation: 4.7),
        Point(months: 72, boy: 116.0, girl: 115.1, standardDeviation: 5.0),
        Point(months: 84, boy: 121.7, girl: 120.8, standardDeviation: 5.3),
        Point(months: 96, boy: 127.3, girl: 126.6, standardDeviation: 5.6),
        Point(months: 108, boy: 132.6, girl: 132.5, standardDeviation: 5.9),
        Point(months: 120, boy: 137.8, girl: 138.6, standardDeviation: 6.3),
        Point(months: 132, boy: 143.1, girl: 145.0, standardDeviation: 6.8),
        Point(months: 144, boy: 149.1, girl: 151.2, standardDeviation: 7.3),
        Point(months: 156, boy: 156.0, girl: 156.4, standardDeviation: 7.6),
        Point(months: 168, boy: 163.2, girl: 159.8, standardDeviation: 7.6),
        Point(months: 192, boy: 172.9, girl: 162.5, standardDeviation: 7.0)
    ]

    /// Typical EU shoe size by age (months), used when no shoe size has been recorded.
    private static let shoeSize: [(months: Double, size: Double)] = [
        (12, 20), (18, 21.5), (24, 23), (36, 25), (48, 27), (60, 28.5),
        (72, 30), (84, 31), (96, 32), (108, 33), (120, 34), (144, 36), (168, 38), (192, 40)
    ]

    static func medianStature(ageMonths: Double, sex: Sex) -> Double {
        interpolate(ageMonths, stature.map { point in
            let value: Double
            switch sex {
            case .boy: value = point.boy
            case .girl: value = point.girl
            case .unspecified: value = (point.boy + point.girl) / 2
            }
            return (point.months, value)
        })
    }

    static func statureStandardDeviation(ageMonths: Double) -> Double {
        interpolate(ageMonths, stature.map { ($0.months, $0.standardDeviation) })
    }

    static func typicalShoeSize(ageMonths: Double) -> Double {
        interpolate(ageMonths, shoeSize)
    }

    private static func interpolate(_ x: Double, _ points: [(Double, Double)]) -> Double {
        guard let first = points.first, let last = points.last else { return 0 }
        if x <= first.0 { return first.1 }
        if x >= last.0 { return last.1 }
        for (lower, upper) in zip(points, points.dropFirst()) where x <= upper.0 {
            let ratio = (x - lower.0) / (upper.0 - lower.0)
            return lower.1 + ratio * (upper.1 - lower.1)
        }
        return last.1
    }
}
