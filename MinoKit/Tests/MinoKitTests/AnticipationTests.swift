import XCTest
@testable import MinoKit

final class AnticipationTests: XCTestCase {
    let leo = Fixtures.leo, ines = Fixtures.ines

    /// Autumn wardrobe for Léo that fits today but lacks winter essentials.
    private var leoAutumn: [WardrobeItem] {
        (0..<5).map { _ in Fixtures.item(.longSleeve) } + (0..<5).map { _ in Fixtures.item(.pants) }
            + [Fixtures.item(.sweater), Fixtures.item(.sweater), Fixtures.item(.raincoat), Fixtures.item(.sneakers)]
            + (0..<4).map { _ in Fixtures.item(.pajamas) } + (0..<3).map { _ in Fixtures.item(.tshirt) }
    }

    func testNoAdviceForAnAlmostEmptyWardrobe() {
        XCTAssertTrue(NeedsForecaster.needs(for: leo, family: [leo], items: [Fixtures.item(.pants)], season: .winter, on: Fixtures.today).isEmpty)
    }

    func testWinterNeeds() {
        let winter = NeedsForecaster.needs(for: leo, family: [leo], items: leoAutumn, season: .winter, on: Fixtures.date(2026, 12, 1))
        XCTAssertEqual(Set(winter.map(\.group)), [.warmOuterwear, .warmShoes, .longSleeveTops, .layers])
        let coat = winter.first { $0.group == .warmOuterwear }
        XCTAssertEqual(coat?.missing, 1)
        XCTAssertEqual(coat?.size, 110)
        XCTAssertEqual(coat?.stillMissing, 1)
    }

    func testFamilyBoxesAndOutgrownSiblingClothesComeFirst() {
        let boxedCoat = Fixtures.item(.coat, owner: nil, size: 110, state: .stored)
        let cousinCoat = Fixtures.item(.coat, owner: nil, size: 110, state: .donated)
        let needs = NeedsForecaster.needs(for: leo, family: [leo, ines], items: leoAutumn + [boxedCoat, cousinCoat], season: .winter, on: Fixtures.date(2026, 12, 1))
        let coat = needs.first { $0.group == .warmOuterwear }
        XCTAssertEqual(coat?.familyStock, [boxedCoat.id])
        XCTAssertEqual(coat?.stillMissing, 0)

        let outgrownByLeo = Fixtures.item(.pants, owner: leo, size: 92)
        let inesItems = (0..<8).map { _ in Fixtures.item(.tshirt, owner: ines, size: 92) }
        let inesNeeds = NeedsForecaster.needs(for: ines, family: [leo, ines], items: inesItems + [outgrownByLeo], season: .winter, on: Fixtures.date(2026, 12, 1))
        XCTAssertEqual(inesNeeds.first { $0.group == .longBottoms }?.familyStock, [outgrownByLeo.id])
    }

    func testFamilyStockForANewChild() {
        let outgrownByLeo = Fixtures.item(.pants, owner: leo, size: 86)
        let stillLeos = Fixtures.item(.pants, owner: leo, size: 110)
        let boxedRoomy = Fixtures.item(.sweater, owner: nil, size: 98, state: .stored)
        let boxedFitting = Fixtures.item(.tshirt, owner: nil, size: 92, state: .stored)
        let donated = Fixtures.item(.tshirt, owner: nil, size: 92, state: .donated)
        let available = FamilyStock.available(for: ines, family: [leo, ines], items: [outgrownByLeo, stillLeos, boxedRoomy, boxedFitting, donated], on: Fixtures.today)
        XCTAssertEqual(available.map(\.id), [outgrownByLeo.id, boxedFitting.id, boxedRoomy.id])
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

final class PassageTests: XCTestCase {
    let leo = Fixtures.leo

    func testTheSeasonalSwitchComesFirstWhenTheNextSizeIsFar() {
        let april = Fixtures.date(2027, 4, 15)
        let passage = Passage.next(for: leo, on: april, calendar: Fixtures.calendar)
        XCTAssertEqual(passage.kind, .season(.summer))
        XCTAssertEqual(passage.date, Fixtures.calendar.startOfDay(for: Fixtures.date(2027, 6, 1)))
        XCTAssertFalse(passage.isUnderway(on: april))
        XCTAssertTrue(passage.isUnderway(on: Fixtures.date(2027, 5, 10)))
    }

    func testASwitchThatJustStartedStaysOpenForTwoWeeks() {
        let passage = Passage.next(for: leo, on: Fixtures.date(2026, 9, 8), calendar: Fixtures.calendar)
        XCTAssertEqual(passage.kind, .season(.autumn))
        XCTAssertEqual(passage.season, .autumn)
    }

    func testTheNextSizeComesFirstWhenItIsSooner() {
        let growing = ChildProfile(
            id: UUID(), name: "A", estimatedBirth: Fixtures.date(2022, 10, 10),
            records: [GrowthRecord(date: Fixtures.today, heightCM: 105.8, shoeSize: 27)]
        )
        let passage = Passage.next(for: growing, on: Fixtures.today, calendar: Fixtures.calendar)
        XCTAssertEqual(passage.kind, .size(110))
        XCTAssertLessThan(passage.date, Fixtures.date(2027, 6, 1))
    }

    func testPlanSortsTakesOverAndLists() {
        let passage = Passage(
            kind: .season(.autumn),
            when: DateEstimate(expected: Fixtures.date(2026, 12, 1), earliest: Fixtures.date(2026, 12, 1), latest: Fixtures.date(2026, 12, 1)),
            season: .winter
        )
        let small = Fixtures.item(.tshirt, size: 98)
        let boxedCoat = Fixtures.item(.coat, owner: nil, size: 110, state: .stored)
        let wardrobe = (0..<6).map { _ in Fixtures.item(.longSleeve) } + (0..<5).map { _ in Fixtures.item(.pants) }
            + (0..<3).map { _ in Fixtures.item(.sweater) } + [Fixtures.item(.sneakers)] + (0..<4).map { _ in Fixtures.item(.pajamas) }
        let plan = PassagePlan(passage: passage, child: leo, family: [leo], items: wardrobe + [small, boxedCoat], covered: [])
        XCTAssertEqual(plan.outgrown, [small.id])
        XCTAssertEqual(plan.fromFamily, [boxedCoat.id])
        XCTAssertEqual(plan.toFind.map(\.group), [.warmShoes])
        XCTAssertFalse(plan.isReady)

        let boots = plan.toFind[0]
        let covered = PassagePlan(passage: passage, child: leo, family: [leo], items: wardrobe + [boxedCoat], covered: [boots.id])
        XCTAssertTrue(covered.isReady)
    }

    func testNeverReadyWithoutKnowingTheWardrobe() {
        let passage = Passage.next(for: leo, on: Fixtures.today, calendar: Fixtures.calendar)
        let plan = PassagePlan(passage: passage, child: leo, family: [leo], items: [Fixtures.item(.tshirt)], covered: [])
        XCTAssertFalse(plan.knowsWardrobe)
        XCTAssertFalse(plan.isReady)
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
        let item = WardrobeItem(ownerID: nil, category: .coat, color: .navy, size: 104, occasion: .dressy, condition: .veryGood)
        let listing = ListingWriter.listing(for: item, brand: "Petit Bateau")
        XCTAssertEqual(listing.title, "Manteau enfant · 4 ans · Petit Bateau")
        XCTAssertTrue(listing.description.contains("Taille : 4 ans · 104 cm"))
        XCTAssertTrue(listing.description.contains("Idéal pour les fêtes"))
        XCTAssertTrue(listing.description.contains("État : Très bon état"))
        XCTAssertTrue(listing.text.hasPrefix(listing.title))
        XCTAssertEqual(ListingWriter.listing(for: item, brand: "  ").title, "Manteau enfant · 4 ans")
    }

    func testShoppingListAndLot() {
        let need = Need(childID: UUID(), group: .warmShoes, season: .winter, size: 28, missing: 1, familyStock: [])
        XCTAssertEqual(ShoppingList.text(for: "Léo", needs: [need]), "Pour Léo :\n• Bottes : 1 en Pointure 28")
        let worn = WardrobeItem(ownerID: nil, category: .tshirt, color: .white, size: 110, condition: .good)
        let lot = ListingWriter.lot(of: [Fixtures.item(.pants, size: 104), worn])
        XCTAssertEqual(lot.title, "Lot de 2 vêtements enfant · 4 ans à 5 ans")
        XCTAssertTrue(lot.description.contains("• Pantalon marine, 4 ans\n"))
        XCTAssertTrue(lot.description.contains("• T-shirt blanc, 5 ans, bon état"))
    }

    func testSeasonalEstimate() {
        let estimate = DayForecast.seasonalEstimate(for: Fixtures.date(2026, 1, 15), calendar: Fixtures.calendar)
        XCTAssertTrue(estimate.isEstimate)
        XCTAssertEqual(estimate.thermal, .cold)
    }
}
