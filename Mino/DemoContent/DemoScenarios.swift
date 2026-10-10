#if DEBUG
import MinoKit
import SwiftData
import SwiftUI
import UIKit

/// Test scenarios for App Store screenshots, at the end of Grandir. Debug builds only: this
/// folder is excluded from Release builds (see project.yml), so it never reaches the App Store.
struct DemoScenariosCard: View {
    @Environment(\.modelContext) private var context
    @State private var done: [DemoScenario: String] = [:]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Scénarios de test", systemImage: "hammer.fill")
                .font(.system(.headline, design: .rounded))
                .foregroundStyle(Theme.ink)
            Text("Visible seulement dans les builds lancées depuis Xcode, jamais sur l'App Store.")
                .font(.footnote)
                .foregroundStyle(Theme.secondaryText)
            ForEach(DemoScenario.allCases) { scenario in
                Button {
                    done[scenario] = DemoLibrary(context: context).run(scenario)
                } label: {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: scenario.symbol)
                            .frame(width: 24)
                            .foregroundStyle(Theme.accent)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(scenario.title)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Theme.ink)
                            Text(done[scenario] ?? scenario.detail)
                                .font(.footnote)
                                .foregroundStyle(done[scenario] == nil ? Theme.secondaryText : Theme.accent)
                                .multilineTextAlignment(.leading)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(12)
                    .background(Theme.chip, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .minoCard()
    }
}

enum DemoScenario: CaseIterable, Identifiable {
    case wardrobe, passage, sibling, event, journal, resale, photos

    var id: Self { self }

    var title: String {
        switch self {
        case .wardrobe: return "1. Dressing de Jeanne, 9 ans"
        case .passage: return "2. Passage au 10 ans dans 3 semaines"
        case .sibling: return "3. Petit frère Léon, 4 ans, et cartons"
        case .event: return "4. Tenue préparée pour un anniversaire"
        case .journal: return "5. Carnet des tenues, avec photo"
        case .resale: return "6. Vêtements en vente"
        case .photos: return "7. Photos de vêtements dans Photos"
        }
    }

    var detail: String {
        switch self {
        case .wardrobe: return "28 vêtements en 9 ans. Écrans Aujourd'hui, Dressing, fiche vêtement."
        case .passage: return "Une mesure à 135,7 cm et trois vêtements devenus petits. Écran Grandir."
        case .sibling: return "Un 2e enfant et les anciens vêtements de Jeanne. Demain, Mode enfant, Famille."
        case .event: return "Dans 3 jours. Carnet des tenues (calendrier en haut à gauche d'Aujourd'hui)."
        case .journal: return "Les 6 derniers jours, dont une photo de tenue."
        case .resale: return "Deux vêtements en vente avec leur état. Dressing › Famille › En vente."
        case .photos: return "Enregistre 12 photos pour tester l'ajout par lot depuis la photothèque."
        }
    }

    var symbol: String {
        switch self {
        case .wardrobe: return "tshirt.fill"
        case .passage: return "ruler.fill"
        case .sibling: return "person.2.fill"
        case .event: return "gift.fill"
        case .journal: return "calendar"
        case .resale: return "tag.fill"
        case .photos: return "photo.on.rectangle.angled"
        }
    }
}

/// Builds the scenarios from real model objects, so every screen computes them as it would
/// for a family. Running a scenario twice does not duplicate anything.
@MainActor
private struct DemoLibrary {
    let context: ModelContext
    private let calendar = Calendar.current
    private let day: TimeInterval = 86_400

    private struct Item {
        let image: String
        let category: GarmentCategory
        let color: GarmentColor
        var size: Int = 134
        var occasion: Occasion = .everyday
    }

    func run(_ scenario: DemoScenario) -> String {
        defer { try? context.save() }
        switch scenario {
        case .wardrobe:
            let jeanne = preparedJeanne()
            return "Prêt : \(jeanne.garments?.count ?? 0) vêtements pour Jeanne."
        case .passage:
            return passage()
        case .sibling:
            return sibling()
        case .event:
            return event()
        case .journal:
            return journal()
        case .resale:
            return resale()
        case .photos:
            return photos()
        }
    }

    // MARK: Scenarios

    /// Jeanne, 9, wears 134 (9 ans); a few pieces in 140 she is growing into.
    private func preparedJeanne() -> Child {
        let jeanne = child(named: "Jeanne") ?? {
            let created = Child(name: "Jeanne", ageInMonths: 108)
            context.insert(created)
            return created
        }()
        // Created at onboarding or by an earlier run: fill her wardrobe only once.
        guard (jeanne.garments ?? []).isEmpty else { return jeanne }
        jeanne.ageInMonths = 108
        addGrowth(to: jeanne, daysAgo: 60, height: 133, shoe: 33)
        let items: [Item] = [
            Item(image: "tshirt-white", category: .tshirt, color: .white),
            Item(image: "tshirt-pink", category: .tshirt, color: .pink),
            Item(image: "tshirt-yellow", category: .tshirt, color: .yellow),
            Item(image: "tshirt-stripes", category: .tshirt, color: .navy),
            Item(image: "longsleeve-stripes", category: .longSleeve, color: .red),
            Item(image: "longsleeve-white", category: .longSleeve, color: .white),
            Item(image: "longsleeve-green", category: .longSleeve, color: .green),
            Item(image: "turtleneck-beige", category: .turtleneck, color: .beige),
            Item(image: "sweater-navy", category: .sweater, color: .navy),
            Item(image: "sweater-red", category: .sweater, color: .red),
            Item(image: "cardigan-pink", category: .cardigan, color: .pink),
            Item(image: "dress-flowers", category: .dress, color: .navy, occasion: .dressy),
            Item(image: "dress-yellow", category: .dress, color: .yellow),
            Item(image: "playsuit-green", category: .playsuit, color: .green),
            Item(image: "pants-denim", category: .pants, color: .denim),
            Item(image: "pants-beige", category: .pants, color: .beige),
            Item(image: "pants-black", category: .pants, color: .black, occasion: .sport),
            Item(image: "overalls-denim", category: .overalls, color: .denim, size: 140),
            Item(image: "skirt-pink", category: .shorts, color: .pink),
            Item(image: "tights-grey", category: .tights, color: .grey),
            Item(image: "tights-pink", category: .tights, color: .pink),
            Item(image: "jacket-denim", category: .lightJacket, color: .denim),
            Item(image: "coat-beige", category: .coat, color: .beige, size: 140),
            Item(image: "raincoat-yellow", category: .raincoat, color: .yellow),
            Item(image: "sneakers-white", category: .sneakers, color: .white, size: 33),
            Item(image: "boots-brown", category: .boots, color: .brown, size: 34),
            Item(image: "beanie-red", category: .coldAccessory, color: .red),
            Item(image: "pajamas-stars", category: .pajamas, color: .purple)
        ]
        for (index, item) in items.enumerated() {
            let garment = insert(item, state: .active, owner: jeanne)
            // A believable history: some pieces worn in the last days, others not for a while.
            garment.lastWornAt = .now.addingTimeInterval(-Double(index % 9 + 1) * day)
            garment.wearCount = 12 - index % 7
        }
        return jeanne
    }

    private func passage() -> String {
        let jeanne = preparedJeanne()
        // 135.7 cm today: she moves into 140 (10 ans) in about three weeks.
        if !(jeanne.growthEntries ?? []).contains(where: { calendar.isDateInToday($0.date) }) {
            addGrowth(to: jeanne, daysAgo: 0, height: 135.7, shoe: 33.4)
        }
        let small: [Item] = [
            Item(image: "tshirt-purple", category: .tshirt, color: .purple, size: 128),
            Item(image: "pants-grey", category: .pants, color: .grey, size: 128),
            Item(image: "cardigan-green", category: .cardigan, color: .green, size: 128)
        ]
        if !owns(jeanne, small[0]) {
            for item in small {
                insert(item, state: .active, owner: jeanne)
            }
        }
        return "Prêt : ouvrez Grandir › Jeanne."
    }

    private func sibling() -> String {
        let jeanne = preparedJeanne()
        guard child(named: "Léon") == nil else { return "Léon est déjà là." }
        let leon = Child(name: "Léon", ageInMonths: 52)
        context.insert(leon)
        addGrowth(to: leon, daysAgo: 30, height: 104.5, shoe: 26)
        let own: [Item] = [
            Item(image: "tshirt-blue", category: .tshirt, color: .blue, size: 104),
            Item(image: "tshirt-green", category: .tshirt, color: .green, size: 104),
            Item(image: "longsleeve-red", category: .longSleeve, color: .red, size: 110),
            Item(image: "sweater-grey", category: .sweater, color: .grey, size: 110),
            Item(image: "pants-navy", category: .pants, color: .navy, size: 104),
            Item(image: "pants-denim", category: .pants, color: .denim, size: 110),
            Item(image: "coat-navy", category: .coat, color: .navy, size: 110),
            Item(image: "sneakers-blue", category: .sneakers, color: .blue, size: 26)
        ]
        for item in own {
            insert(item, state: .active, owner: leon)
        }
        // Jeanne's old clothes, waiting in the family boxes: they fit Léon now.
        let boxes: [Item] = [
            Item(image: "sweater-yellow", category: .sweater, color: .yellow, size: 110),
            Item(image: "raincoat-red", category: .raincoat, color: .red, size: 110),
            Item(image: "longsleeve-white", category: .longSleeve, color: .white, size: 110),
            Item(image: "pants-beige", category: .pants, color: .beige, size: 110)
        ]
        for item in boxes {
            insert(item, state: .stored, owner: nil).lastOwnerID = jeanne.id
        }
        return "Prêt : Léon a 8 vêtements, 4 l'attendent dans les cartons."
    }

    private func event() -> String {
        let jeanne = preparedJeanne()
        let date = calendar.startOfDay(for: .now.addingTimeInterval(3 * day))
        let chosen = pieces(of: jeanne, [
            (.onePiece, .dress, .navy), (.legwear, .tights, .grey), (.layer, .cardigan, .pink), (.shoes, .sneakers, .white)
        ])
        let plan = replacePlan(for: jeanne, on: date)
        plan.context = .celebration
        plan.note = "Anniversaire de Lina"
        plan.piecesRaw = chosen.map(\.rawValue)
        return "Prêt : \(Formatting.longDate(date)), dans le carnet."
    }

    private func journal() -> String {
        let jeanne = preparedJeanne()
        let outfits: [[(OutfitSlot, GarmentCategory, GarmentColor)]] = [
            [(.top, .longSleeve, .white), (.bottom, .pants, .denim), (.layer, .sweater, .navy), (.shoes, .sneakers, .white)],
            [(.top, .longSleeve, .red), (.layer, .cardigan, .pink), (.bottom, .shorts, .pink), (.legwear, .tights, .grey),
             (.shoes, .sneakers, .white), (.accessory, .coldAccessory, .red)],
            [(.top, .turtleneck, .beige), (.bottom, .pants, .beige), (.layer, .sweater, .red), (.shoes, .boots, .brown)],
            [(.onePiece, .dress, .yellow), (.legwear, .tights, .pink), (.layer, .cardigan, .pink), (.shoes, .sneakers, .white)],
            [(.top, .tshirt, .navy), (.bottom, .pants, .black), (.outerwear, .lightJacket, .denim), (.shoes, .sneakers, .white)],
            [(.top, .longSleeve, .green), (.bottom, .pants, .denim), (.outerwear, .raincoat, .yellow), (.shoes, .boots, .brown)]
        ]
        let photo = resource("DemoOutfitPhoto", "jpg")
        for (offset, outfit) in outfits.enumerated() {
            let date = calendar.startOfDay(for: .now.addingTimeInterval(-Double(offset + 1) * day))
            let chosen = pieces(of: jeanne, outfit)
            let plan = replacePlan(for: jeanne, on: date)
            plan.context = calendar.isDateInWeekend(date) ? .outing : .school
            plan.piecesRaw = chosen.map(\.rawValue)
            plan.proposedRaw = plan.piecesRaw
            plan.confirmedAt = date.addingTimeInterval(8 * 3600)
            // The striped outfit is the one in the photo.
            if offset == 1 { plan.photo = photo }
        }
        return "Prêt : 6 tenues, dont une photo il y a 2 jours."
    }

    private func resale() -> String {
        let jeanne = preparedJeanne()
        let items: [(Item, Condition)] = [
            (Item(image: "dress-yellow", category: .dress, color: .yellow, size: 128), .veryGood),
            (Item(image: "sweater-yellow", category: .sweater, color: .yellow, size: 128), .good)
        ]
        let listed = (try? context.fetch(FetchDescriptor<Garment>())) ?? []
        guard !listed.contains(where: { $0.state == .forSale }) else { return "Déjà en vente." }
        for (item, condition) in items {
            let garment = insert(item, state: .forSale, owner: nil)
            garment.lastOwnerID = jeanne.id
            garment.condition = condition
        }
        return "Prêt : 2 vêtements de Jeanne en vente."
    }

    /// Photos on a light table, like a parent would take them, for the batch add from the library.
    private func photos() -> String {
        let names = ["tshirt-yellow", "sweater-navy", "pants-denim", "dress-flowers", "cardigan-pink", "longsleeve-stripes",
                     "skirt-pink", "jacket-denim", "sneakers-white", "boots-brown", "raincoat-yellow", "beanie-red"]
        var saved = 0
        for name in names {
            guard let data = resource("DemoGarment-\(name)", "png"), let garment = UIImage(data: data) else { continue }
            let size = CGSize(width: 1200, height: 1500)
            let photo = UIGraphicsImageRenderer(size: size).image { _ in
                UIColor(red: 0.95, green: 0.93, blue: 0.89, alpha: 1).setFill()
                UIRectFill(CGRect(origin: .zero, size: size))
                garment.draw(in: CGRect(x: 150, y: 300, width: 900, height: 900))
            }
            UIImageWriteToSavedPhotosAlbum(photo, nil, nil, nil)
            saved += 1
        }
        return "Envoyé : \(saved) photos (autorisez l'accès à Photos si iOS le demande)."
    }

    // MARK: Helpers

    private func child(named name: String) -> Child? {
        let children = (try? context.fetch(FetchDescriptor<Child>())) ?? []
        return children.first { $0.name == name }
    }

    private func owns(_ child: Child, _ item: Item) -> Bool {
        (child.garments ?? []).contains { $0.category == item.category && $0.color == item.color && $0.size == item.size }
    }

    private func addGrowth(to child: Child, daysAgo: Double, height: Double, shoe: Double) {
        let entry = GrowthEntry(date: .now.addingTimeInterval(-daysAgo * day), heightCM: height, shoeSize: shoe, isApproximate: false)
        context.insert(entry)
        entry.child = child
    }

    @discardableResult
    private func insert(_ item: Item, state: LifecycleState, owner: Child?) -> Garment {
        let garment = Garment(
            photo: resource("DemoGarment-\(item.image)", "png"), category: item.category, color: item.color,
            size: item.size, occasion: item.occasion, brand: "", state: state
        )
        context.insert(garment)
        garment.owner = owner
        return garment
    }

    private func pieces(of child: Child, _ wanted: [(OutfitSlot, GarmentCategory, GarmentColor)]) -> [OutfitPiece] {
        wanted.compactMap { slot, category, color in
            (child.garments ?? [])
                .first { $0.state == .active && $0.category == category && $0.color == color }
                .map { OutfitPiece(slot: slot, itemID: $0.id) }
        }
    }

    /// A fresh plan for that child and day, replacing any previous one.
    private func replacePlan(for child: Child, on date: Date) -> PlannedOutfit {
        for existing in child.plans ?? [] where calendar.isDate(existing.day, inSameDayAs: date) {
            context.delete(existing)
        }
        let plan = PlannedOutfit(day: date)
        context.insert(plan)
        plan.child = child
        return plan
    }

    private func resource(_ name: String, _ ext: String) -> Data? {
        Bundle.main.url(forResource: name, withExtension: ext).flatMap { try? Data(contentsOf: $0) }
    }
}
#endif
