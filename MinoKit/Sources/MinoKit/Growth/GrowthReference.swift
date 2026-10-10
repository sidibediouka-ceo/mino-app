import Foundation

/// Reference curves derived from the WHO Child Growth Standards (0–5 years) and the
/// WHO 2007 growth reference (5–16 years), averaged across girls and boys: Mino never asks
/// for a child's sex, and the projection is anchored on the child's own sizes anyway.
/// Values are rounded; Mino is not a medical tool.
enum GrowthReference {
    private static let stature: [(months: Double, median: Double, standardDeviation: Double)] = [
        (0, 49.5, 1.9), (3, 60.6, 2.2), (6, 66.7, 2.4), (9, 71.1, 2.6), (12, 74.9, 2.7),
        (18, 81.5, 3.0), (24, 86.1, 3.2), (36, 95.6, 3.8), (48, 103.0, 4.3), (60, 109.7, 4.8),
        (72, 115.6, 5.1), (84, 121.3, 5.4), (96, 127.0, 5.7), (108, 132.6, 6.0), (120, 138.2, 6.4),
        (132, 144.1, 7.0), (144, 150.2, 7.5), (156, 156.2, 7.7), (168, 161.5, 7.8), (192, 167.7, 8.6)
    ]

    /// Typical EU shoe size by age (months), used when no shoe size has been recorded.
    private static let shoeSize: [(months: Double, size: Double)] = [
        (12, 20), (18, 21.5), (24, 23), (36, 25), (48, 27), (60, 28.5),
        (72, 30), (84, 31), (96, 32), (108, 33), (120, 34), (144, 36), (168, 38), (192, 40)
    ]

    static func medianStature(ageMonths: Double) -> Double {
        interpolate(ageMonths, stature.map { ($0.months, $0.median) })
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
