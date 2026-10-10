import XCTest
@testable import MinoKit

final class FitTests: XCTestCase {
    let leo = Fixtures.leo

    func testClothingFitBands() {
        XCTAssertEqual(leo.fit(of: Fixtures.item(.pants, size: 98), on: Fixtures.today), .tooSmall)
        XCTAssertEqual(leo.fit(of: Fixtures.item(.pants, size: 104), on: Fixtures.today), .fits)
        XCTAssertEqual(leo.fit(of: Fixtures.item(.pants, size: 110), on: Fixtures.today), .fits)
        XCTAssertEqual(leo.fit(of: Fixtures.item(.pants, size: 116), on: Fixtures.today), .roomy)
        XCTAssertEqual(leo.fit(of: Fixtures.item(.pants, size: 128), on: Fixtures.today), .tooBig)
    }

    func testShoeFitBands() {
        XCTAssertEqual(leo.fit(of: Fixtures.item(.sneakers, size: 26), on: Fixtures.today), .tooSmall)
        XCTAssertEqual(leo.fit(of: Fixtures.item(.sneakers, size: 27), on: Fixtures.today), .fits)
        XCTAssertEqual(leo.fit(of: Fixtures.item(.sneakers, size: 28), on: Fixtures.today), .fits)
        XCTAssertEqual(leo.fit(of: Fixtures.item(.sneakers, size: 29), on: Fixtures.today), .roomy)
    }

    func testStillFitsConfirmationExtendsTheUpperBound() {
        let confirmed = WardrobeItem(ownerID: leo.id, category: .pants, color: .navy, size: 98, fitConfirmedAt: 103)
        XCTAssertEqual(leo.fit(of: confirmed, on: Fixtures.today), .fits)
    }

    func testDateWhenABigGarmentStartsToFit() throws {
        let big = Fixtures.item(.coat, size: 122)
        let estimate = try XCTUnwrap(leo.dateItemFits(big, from: Fixtures.today))
        XCTAssertEqual(leo.fit(of: big, on: estimate.expected.addingTimeInterval(14 * 86_400)), .fits)
    }
}
