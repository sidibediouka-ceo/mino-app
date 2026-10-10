import XCTest
@testable import MinoKit

final class AnticipationTests: XCTestCase {
    let forecaster = NeedsForecaster(calendar: Fixtures.calendar)
    let leo = Fixtures.leo, ines = Fixtures.ines

    /// Autumn wardrobe for Léo that fits today but lacks winter essentials.
    private var leoAutumn: [WardrobeItem] {
        (0..<5).map { _ in Fixtures.item(.longSleeve) } + (0..<5).map { _ in Fixtures.item(.pants) }
            + [Fixtures.item(.sweater), Fixtures.item(.sweater), Fixtures.item(.raincoat), Fixtures.item(.sneakers)]
            + (0..<4).map { _ in Fixtures.item(.pajamas) } + (0..<3).map { _ in Fixtures.item(.tshirt) }
    }

    func testNoAdviceForAnAlmostEmptyWardrobe() {
        XCTAssertTrue(forecaster.needs(for: leo, family: [leo], items: [Fixtures.item(.pants)], on: Fixtures.today).isEmpty)
    }

    func testWinterNeedsAreAnticipatedBeforeTheSeason() {
        let needs = forecaster.needs(for: leo, family: [leo], items: leoAutumn, on: Fixtures.date(2026, 11, 1))
        let winter = needs.filter { $0.season == .winter }
        XCTAssertEqual(Set(winter.map(\.group)), [.warmOuterwear, .warmShoes, .longSleeveTops, .layers])
        let coat = try? XCTUnwrap(winter.first { $0.group == .warmOuterwear })
        XCTAssertEqual(coat?.missing, 1)
        XCTAssertEqual(coat?.size, 110)
        XCTAssertEqual(coat?.stillMissing, 1)
    }

    func testFamilyBoxesAndOutgrownSiblingClothesComeFirst() {
        let boxedCoat = Fixtures.item(.coat, owner: nil, size: 110, state: .stored)
        let cousinCoat = Fixtures.item(.coat, owner: nil, size: 110, state: .donated)
        let needs = forecaster.needs(for: leo, family: [leo, ines], items: leoAutumn + [boxedCoat, cousinCoat], on: Fixtures.date(2026, 11, 1))
        let coat = needs.first { $0.group == .warmOuterwear }
        XCTAssertEqual(coat?.familyStock, [boxedCoat.id])
        XCTAssertEqual(coat?.stillMissing, 0)

        let outgrownByLeo = Fixtures.item(.pants, owner: leo, size: 92)
        let inesItems = (0..<8).map { _ in Fixtures.item(.tshirt, owner: ines, size: 92) }
        let inesNeeds = forecaster.needs(for: ines, family: [leo, ines], items: inesItems + [outgrownByLeo], on: Fixtures.date(2026, 11, 1))
        XCTAssertEqual(inesNeeds.first { $0.group == .longBottoms }?.familyStock, [outgrownByLeo.id])
    }

    func testLifecycleRecommendations() {
        let fitsInesNow = Fixtures.item(.pants, owner: leo, size: 86)
        XCTAssertEqual(LifecycleAdvisor.recommend(for: fitsInesNow, family: [leo, ines], on: Fixtures.today), .sibling(ines.id, fitsFrom: nil))

        let fitsInesSoon = Fixtures.item(.pants, owner: leo, size: 98)
        if case let .sibling(id, fitsFrom) = LifecycleAdvisor.recommend(for: fitsInesSoon, family: [leo, ines], on: Fixtures.today) {
            XCTAssertEqual(id, ines.id)
            XCTAssertNotNil(fitsFrom)
        } else {
            XCTFail("expected a sibling recommendation")
        }

        let fitsInesMuchLater = Fixtures.item(.pants, owner: leo, size: 104)
        XCTAssertEqual(LifecycleAdvisor.recommend(for: fitsInesMuchLater, family: [leo, ines], on: Fixtures.today), .store)

        XCTAssertEqual(LifecycleAdvisor.recommend(for: Fixtures.item(.coat, size: 98), family: [leo], on: Fixtures.today), .sell)
        XCTAssertEqual(LifecycleAdvisor.recommend(for: Fixtures.item(.tshirt, size: 98), family: [leo], on: Fixtures.today), .donate)
    }

    func testSeasons() {
        XCTAssertEqual(Season.of(Fixtures.date(2026, 12, 25), calendar: Fixtures.calendar), .winter)
        XCTAssertEqual(Season.winter.nextStart(after: Fixtures.today, calendar: Fixtures.calendar), Fixtures.calendar.startOfDay(for: Fixtures.date(2026, 12, 1)))
    }
}

final class BriefingTests: XCTestCase {
    func testSortThenRetrieveThenMeasure() {
        let leo = Fixtures.leo
        let outgrown = Fixtures.item(.pants, size: 92)
        let boxed = Fixtures.item(.coat, owner: nil, size: 110, state: .stored)
        let need = Need(childID: leo.id, group: .warmOuterwear, season: .winter, neededBy: Fixtures.today, size: 110, missing: 1, familyStock: [boxed.id])
        let unmeasured = ChildProfile(id: UUID(), name: "A", birthDate: Fixtures.date(2022, 1, 1), sex: .girl, records: [])
        let briefing = Briefing.compose(family: [unmeasured, leo], items: [outgrown, boxed], needs: [need], on: Fixtures.today)
        XCTAssertEqual(briefing, [.sort(childID: leo.id, itemIDs: [outgrown.id]), .retrieve(need), .measure(childID: unmeasured.id)])
        XCTAssertEqual(briefing.map(\.childID), [leo.id, leo.id, unmeasured.id])
    }

    func testNothingToDoForAMeasuredChildWithAFittingWardrobe() {
        let items = (0..<8).map { _ in Fixtures.item(.tshirt) }
        XCTAssertTrue(Briefing.compose(family: [Fixtures.leo], items: items, needs: [], on: Fixtures.today).isEmpty)
    }
}

final class RecognitionAndListingTests: XCTestCase {
    func testCategoryGuess() {
        XCTAssertEqual(CategoryGuess.ranked(fromLabels: [("raincoat", 0.6), ("coat", 0.3)]), [.raincoat, .coat])
        XCTAssertEqual(CategoryGuess.ranked(fromLabels: [("t_shirt", 0.5), ("shirt", 0.2)]), [.tshirt, .longSleeve])
        XCTAssertEqual(CategoryGuess.ranked(fromLabels: [("jeans", 0.4)]), [.pants])
        XCTAssertEqual(CategoryGuess.ranked(fromLabels: [("dog", 0.9), ("dress", 0.05)]), [])
    }

    func testDominantColour() {
        let navy = RGBColor(red: 0.12, green: 0.18, blue: 0.35)
        XCTAssertEqual(GarmentColor.dominant(in: Array(repeating: navy, count: 10)), .navy)
        let mixed = [RGBColor(red: 0.8, green: 0.2, blue: 0.2), RGBColor(red: 0.3, green: 0.55, blue: 0.85), RGBColor(red: 0.95, green: 0.83, blue: 0.3)]
        XCTAssertEqual(GarmentColor.dominant(in: mixed), .multicolor)
        XCTAssertNil(GarmentColor.dominant(in: []))
    }

    func testListing() {
        let item = WardrobeItem(ownerID: nil, category: .coat, color: .navy, size: 104, occasion: .dressy)
        let listing = ListingWriter.listing(for: item, brand: "Petit Bateau")
        XCTAssertEqual(listing.title, "Manteau enfant · 4 ans · Petit Bateau")
        XCTAssertTrue(listing.description.contains("Taille : 4 ans · 104 cm"))
        XCTAssertTrue(listing.description.contains("Style : habillé"))
        XCTAssertTrue(listing.text.hasPrefix(listing.title))
        XCTAssertEqual(ListingWriter.listing(for: item, brand: "  ").title, "Manteau enfant · 4 ans")
    }

    func testSeasonalEstimate() {
        let estimate = DayForecast.seasonalEstimate(for: Fixtures.date(2026, 1, 15), calendar: Fixtures.calendar)
        XCTAssertTrue(estimate.isEstimate)
        XCTAssertEqual(estimate.thermal, .cold)
    }
}
