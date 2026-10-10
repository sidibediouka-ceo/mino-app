import XCTest
@testable import MinoKit

final class GrowthTests: XCTestCase {
    func testWithoutRecordsTheReferenceMedianIsUsedWithAWideBand() {
        let child = ChildProfile(id: UUID(), name: "A", birthDate: Fixtures.date(2021, 10, 10), sex: .girl, records: [])
        let estimate = child.height(at: Fixtures.today)
        XCTAssertEqual(estimate.expected, 109.4, accuracy: 0.5)
        XCTAssertGreaterThan(estimate.high - estimate.low, 8)
    }

    func testATallChildStaysOnHerGrowthChannel() {
        let tall = ChildProfile(
            id: UUID(), name: "A", birthDate: Fixtures.date(2022, 10, 10), sex: .girl,
            records: [GrowthRecord(date: Fixtures.today, heightCM: 110, shoeSize: nil)]
        )
        let inOneYear = Fixtures.date(2027, 10, 10)
        let projected = tall.height(at: inOneYear).expected
        let median = GrowthReference.medianStature(ageMonths: 60, sex: .girl)
        XCTAssertGreaterThan(projected, median + 5)
        XCTAssertLessThan(projected, 120)
    }

    func testUncertaintyGrowsWithTheHorizonAndHeightNeverDecreases() {
        let near = Fixtures.leo.height(at: Fixtures.date(2026, 12, 10))
        let far = Fixtures.leo.height(at: Fixtures.date(2027, 10, 10))
        XCTAssertLessThan(near.high - near.low, far.high - far.low)
        XCTAssertGreaterThanOrEqual(near.expected, 104)
        XCTAssertGreaterThan(far.expected, near.expected)
    }

    func testApproximateRecordsAreLessCertainThanMeasurements() {
        let approximate = ChildProfile(
            id: UUID(), name: "A", birthDate: Fixtures.date(2022, 10, 10), sex: .boy,
            records: [GrowthRecord(date: Fixtures.today, heightCM: 104, shoeSize: nil, isApproximate: true)]
        )
        let a = approximate.height(at: Fixtures.today), m = Fixtures.leo.height(at: Fixtures.today)
        XCTAssertGreaterThan(a.high - a.low, m.high - m.low)
        XCTAssertNil(approximate.lastMeasuredHeightDate)
        XCTAssertEqual(Fixtures.leo.lastMeasuredHeightDate, Fixtures.today)
    }

    func testDateReachingIsOrderedAndPlausible() throws {
        let estimate = try XCTUnwrap(Fixtures.leo.dateReaching(heightCM: 110, from: Fixtures.today))
        XCTAssertLessThanOrEqual(estimate.earliest, estimate.expected)
        XCTAssertLessThanOrEqual(estimate.expected, estimate.latest)
        let months = estimate.expected.timeIntervalSince(Fixtures.today) / (30.4 * 86_400)
        XCTAssertGreaterThan(months, 6)
        XCTAssertLessThan(months, 16)
    }

    func testShoeSizeFollowsTheRecordedOffset() {
        let inAYear = Fixtures.leo.shoeSize(at: Fixtures.date(2027, 10, 10)).expected
        XCTAssertEqual(inAYear, 28.5, accuracy: 0.6)
        XCTAssertEqual(Fixtures.leo.shoeSize(at: Fixtures.today).expected, 27, accuracy: 0.01)
    }

    func testNextSizeMilestones() throws {
        XCTAssertEqual(Fixtures.leo.currentSize(.clothing, on: Fixtures.today), 104)
        let clothing = try XCTUnwrap(Fixtures.leo.nextSize(.clothing, after: Fixtures.today))
        XCTAssertEqual(clothing.size, 110)
        XCTAssertGreaterThan(clothing.when.expected, Fixtures.today)
        let shoes = try XCTUnwrap(Fixtures.leo.nextSize(.shoes, after: Fixtures.today))
        XCTAssertEqual(shoes.size, 28)
    }
}
