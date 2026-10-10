import XCTest
@testable import MinoKit

final class OutfitEngineTests: XCTestCase {
    let engine = OutfitEngine(calendar: Fixtures.calendar)
    let leo = Fixtures.leo

    private func categories(_ outfit: Outfit, _ items: [WardrobeItem]) -> [GarmentCategory] {
        outfit.pieces.compactMap { piece in items.first { $0.id == piece.itemID }?.category }
    }

    private var fullWardrobe: [WardrobeItem] {
        [
            Fixtures.item(.tshirt), Fixtures.item(.longSleeve), Fixtures.item(.sweater),
            Fixtures.item(.pants), Fixtures.item(.shorts), Fixtures.item(.coat), Fixtures.item(.raincoat),
            Fixtures.item(.lightJacket), Fixtures.item(.sneakers), Fixtures.item(.boots), Fixtures.item(.sandals),
            Fixtures.item(.coldAccessory), Fixtures.item(.pajamas)
        ]
    }

    func testColdRainyMorningLayersUpInDressingOrder() {
        let items = fullWardrobe
        let outfit = engine.propose(child: leo, items: items, weather: Fixtures.weather(morning: 7, high: 11, rain: 0.7), context: .school)
        XCTAssertEqual(categories(outfit, items), [.pants, .longSleeve, .sweater, .boots, .raincoat])
        XCTAssertTrue(outfit.gaps.isEmpty)
        XCTAssertEqual(outfit.reasons, ["Frais : le pull", "Pluie prévue : les bottes et l'imperméable"])
    }

    func testFreezingDayAddsCoatAndAccessory() {
        let items = fullWardrobe
        let outfit = engine.propose(child: leo, items: items, weather: Fixtures.weather(morning: -1, high: 4), context: .school)
        XCTAssertEqual(categories(outfit, items), [.pants, .longSleeve, .sweater, .boots, .coat, .coldAccessory])
        XCTAssertEqual(outfit.reasons, ["Très froid : le pull, le manteau et le bonnet"])
    }

    func testHotDayIsLight() {
        let items = fullWardrobe
        let outfit = engine.propose(child: leo, items: items, weather: Fixtures.weather(morning: 26, high: 33), context: .outing)
        XCTAssertEqual(categories(outfit, items), [.shorts, .tshirt, .sandals])
    }

    func testHomeDaySkipsShoesAndOuterwear() {
        let items = fullWardrobe
        let outfit = engine.propose(child: leo, items: items, weather: Fixtures.weather(morning: 7, high: 11, rain: 0.7), context: .home)
        XCTAssertEqual(categories(outfit, items), [.pants, .longSleeve, .sweater])
    }

    func testOutgrownGarmentsAreNeverProposedAndMissingOnesAreReported() {
        let items = [Fixtures.item(.pants), Fixtures.item(.longSleeve), Fixtures.item(.sweater), Fixtures.item(.coat, size: 98), Fixtures.item(.sneakers)]
        let outfit = engine.propose(child: leo, items: items, weather: Fixtures.weather(morning: 4, high: 8), context: .school)
        XCTAssertFalse(categories(outfit, items).contains(.coat))
        XCTAssertEqual(outfit.gaps, [.outerwear])
    }

    func testYesterdaysGarmentRestsToday() {
        let yesterday = Fixtures.date(2026, 10, 9)
        let worn = Fixtures.item(.pants, lastWornAt: yesterday)
        let fresh = Fixtures.item(.pants, color: .grey)
        let items = [worn, fresh, Fixtures.item(.longSleeve, color: .white)]
        let outfit = engine.propose(child: leo, items: items, weather: Fixtures.weather(morning: 14, high: 18), context: .home)
        XCTAssertTrue(outfit.pieces.contains(OutfitPiece(slot: .bottom, itemID: fresh.id)))
    }

    func testTomorrowAvoidsWhatIsPlannedForToday() {
        let today = Fixtures.today
        let tomorrow = Fixtures.date(2026, 10, 11)
        let items = [Fixtures.item(.pants), Fixtures.item(.pants, color: .grey), Fixtures.item(.longSleeve, color: .white)]
        let weather = { (date: Date) in Fixtures.weather(morning: 14, high: 18, on: date) }
        let todays = engine.propose(child: leo, items: items, weather: weather(today), context: .home)
        let plannedBottom = try? XCTUnwrap(todays.pieces.first { $0.slot == .bottom }?.itemID)
        let rotated = items.map { $0.id == plannedBottom ? $0.worn(on: today) : $0 }
        let tomorrows = engine.propose(child: leo, items: rotated, weather: weather(tomorrow), context: .home)
        XCTAssertNotEqual(tomorrows.pieces.first { $0.slot == .bottom }?.itemID, plannedBottom)
        XCTAssertEqual(rotated.first { $0.id == plannedBottom }?.lastWornAt, today)
    }

    func testSportExcludesDressesAndPrefersSportswear() {
        let ines = Fixtures.ines
        let dress = Fixtures.item(.dress, owner: ines, size: 92)
        let joggers = Fixtures.item(.pants, owner: ines, size: 92, occasion: .sport)
        let jeans = Fixtures.item(.pants, owner: ines, size: 92, color: .denim)
        let items = [dress, joggers, jeans, Fixtures.item(.tshirt, owner: ines, size: 92, color: .white), Fixtures.item(.sneakers, owner: ines, size: 23)]
        let outfit = engine.propose(child: ines, items: items, weather: Fixtures.weather(morning: 18, high: 24), context: .sport)
        XCTAssertFalse(outfit.pieces.contains { $0.itemID == dress.id })
        XCTAssertTrue(outfit.pieces.contains(OutfitPiece(slot: .bottom, itemID: joggers.id)))
        XCTAssertEqual(outfit.reasons.last, "Jour de sport : tenue souple et baskets")
    }

    func testCelebrationFavoursTheDressyDress() {
        let ines = Fixtures.ines
        let dress = Fixtures.item(.dress, owner: ines, size: 92, color: .pink, occasion: .dressy)
        let items = [dress, Fixtures.item(.pants, owner: ines, size: 92), Fixtures.item(.tshirt, owner: ines, size: 92), Fixtures.item(.sneakers, owner: ines, size: 23)]
        let outfit = engine.propose(child: ines, items: items, weather: Fixtures.weather(morning: 20, high: 25), context: .celebration)
        XCTAssertEqual(outfit.pieces.first, OutfitPiece(slot: .dress, itemID: dress.id))
    }

    func testColoursThatClashAreAvoided() {
        let red = Fixtures.item(.longSleeve, color: .red)
        let green = Fixtures.item(.pants, color: .green)
        let grey = Fixtures.item(.pants, color: .grey)
        let outfit = engine.propose(child: leo, items: [red, green, grey], weather: Fixtures.weather(morning: 15, high: 19), context: .home)
        XCTAssertTrue(outfit.pieces.contains(OutfitPiece(slot: .bottom, itemID: grey.id)))
    }

    func testAlternativesExcludeTheCurrentPieceAndUnsuitableOnes() {
        let a = Fixtures.item(.longSleeve), b = Fixtures.item(.longSleeve, color: .white), small = Fixtures.item(.longSleeve, size: 92)
        let items = [a, b, small, Fixtures.item(.pants)]
        let weather = Fixtures.weather(morning: 15, high: 19)
        let outfit = engine.propose(child: leo, items: items, weather: weather, context: .home)
        let current = try? XCTUnwrap(outfit.pieces.first { $0.slot == .top }?.itemID)
        let alternatives = engine.alternatives(for: .top, in: outfit, child: leo, items: items, weather: weather, context: .home)
        XCTAssertEqual(alternatives.count, 1)
        XCTAssertNotEqual(alternatives.first, current)
        XCTAssertFalse(alternatives.contains(small.id))
    }

    func testForgottenGarmentIsMentioned() {
        let forgotten = Fixtures.item(.dress, owner: Fixtures.ines, size: 92, lastWornAt: Fixtures.date(2026, 9, 20))
        let outfit = engine.propose(child: Fixtures.ines, items: [forgotten], weather: Fixtures.weather(morning: 20, high: 25), context: .home)
        XCTAssertEqual(outfit.reasons, ["Belle journée : une tenue légère", "Journée à la maison : le confort d'abord"])
        let outing = engine.propose(child: Fixtures.ines, items: [forgotten], weather: Fixtures.weather(morning: 20, high: 25), context: .outing)
        XCTAssertEqual(outing.reasons.last, "La robe n'a pas été portée depuis 20 jours")
    }

    func testReplacingKeepsDressingOrderAndPiecesRoundTrip() {
        let id = UUID()
        let outfit = Outfit(pieces: [OutfitPiece(slot: .shoes, itemID: UUID()), OutfitPiece(slot: .top, itemID: UUID())], gaps: [], reasons: [])
        let replaced = outfit.replacing(.top, with: id)
        XCTAssertEqual(replaced.pieces.map(\.slot), [.top, .shoes])
        XCTAssertEqual(replaced.pieces.first?.itemID, id)
        let piece = OutfitPiece(slot: .layer, itemID: id)
        XCTAssertEqual(OutfitPiece(rawValue: piece.rawValue), piece)
        XCTAssertNil(OutfitPiece(rawValue: "nonsense"))
    }
}

final class RoutineAndLearningTests: XCTestCase {
    func testDefaultsThenLearnsTheWeek() {
        let wednesday = Fixtures.date(2026, 10, 14), saturday = Fixtures.date(2026, 10, 10)
        var routine = WeeklyRoutine(rawValue: "")
        XCTAssertEqual(routine.context(on: wednesday, calendar: Fixtures.calendar), .school)
        XCTAssertEqual(routine.context(on: saturday, calendar: Fixtures.calendar), .outing)
        routine = routine.learning(.sport, on: wednesday, calendar: Fixtures.calendar)
        XCTAssertEqual(routine.rawValue, "4=sport")
        XCTAssertEqual(WeeklyRoutine(rawValue: routine.rawValue).context(on: Fixtures.date(2026, 10, 21), calendar: Fixtures.calendar), .sport)
        XCTAssertEqual(WeeklyRoutine(rawValue: "garbage;9=x").rawValue, "")
    }

    func testOnlyMeaningfulContextsAreOffered() {
        XCTAssertEqual(DayContext.offered(for: [.everyday], current: .school), [.school, .outing, .home])
        XCTAssertEqual(DayContext.offered(for: [.everyday, .sport], current: .school), [.school, .sport, .outing, .home])
        XCTAssertEqual(DayContext.offered(for: [.everyday], current: .celebration), [.school, .outing, .celebration, .home])
    }

    func testAffinityChanges() {
        let kept = UUID(), rejected = UUID(), chosen = UUID()
        let changes = PreferenceLearning.affinityChanges(
            proposed: [OutfitPiece(slot: .top, itemID: kept), OutfitPiece(slot: .bottom, itemID: rejected)],
            worn: [OutfitPiece(slot: .top, itemID: kept), OutfitPiece(slot: .bottom, itemID: chosen)]
        )
        XCTAssertEqual(changes, [kept: 0.15, rejected: -0.3, chosen: 0.3])
        XCTAssertEqual(PreferenceLearning.applying(0.3, to: 1.9), 2)
        XCTAssertEqual(PreferenceLearning.applying(-0.3, to: -1.9), -2)
    }
}
