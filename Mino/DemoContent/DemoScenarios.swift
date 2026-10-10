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
        case .journal: return "5. Carnet des tenues du mois"
        case .resale: return "6. Vêtements en vente"
        case .photos: return "7. Photos de vêtements dans Photos"
        }
    }

    var detail: String {
        switch self {
        case .wardrobe: return "Ses vêtements en 9 ans, ceux dont la photo est fournie. Aujourd'hui, Dressing, fiche."
        case .passage: return "Une mesure à 135,7 cm et trois affaires devenues petites. Écran Grandir."
        case .sibling: return "26 vêtements à lui et 4 qui l'attendent dans les cartons. Demain, Mode enfant, Famille."
        case .event: return "Dans 3 jours. Carnet des tenues (calendrier en haut à gauche d'Aujourd'hui)."
        case .journal: return "Une tenue par jour depuis le 1er du mois, pour Jeanne et Léon."
        case .resale: return "Deux paires de baskets devenues petites, en vente. Dressing › Famille › En vente."
        case .photos: return "Enregistre les photos de vêtements fournies, pour tester l'ajout par lot."
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
        // Created at onboarding or by an earlier run: set her up once, then only add the
        // garments whose photos arrived since.
        if !(jeanne.growthEntries ?? []).contains(where: { !$0.isApproximate }) {
            jeanne.ageInMonths = 108
            addGrowth(to: jeanne, daysAgo: 60, height: 133, shoe: 33)
        }
        let items: [Item] = [
            Item(image: "tshirt-ruffle", category: .tshirt, color: .white),
            Item(image: "longsleeve-stripes", category: .longSleeve, color: .navy),
            Item(image: "hoodie-lilac", category: .sweater, color: .purple),
            Item(image: "cardigan-cream", category: .cardigan, color: .white),
            Item(image: "dress-pink", category: .dress, color: .pink, occasion: .dressy),
            Item(image: "jeans-wide", category: .pants, color: .denim),
            Item(image: "leggings-pink", category: .pants, color: .pink),
            Item(image: "skirt-pink", category: .shorts, color: .pink),
            Item(image: "jacket-denim", category: .lightJacket, color: .denim),
            Item(image: "jacket-flowers", category: .lightJacket, color: .multicolor),
            Item(image: "tights-grey", category: .tights, color: .grey),
            Item(image: "tights-pink", category: .tights, color: .pink),
            Item(image: "tights-dots", category: .tights, color: .white),
            Item(image: "tights-navy", category: .tights, color: .navy),
            Item(image: "sneakers-flowers", category: .sneakers, color: .white, size: 33),
            Item(image: "sneakers-lilac", category: .sneakers, color: .purple, size: 33),
            Item(image: "sneakers-camel", category: .sneakers, color: .brown, size: 33)
        ]
        for (index, item) in items.enumerated() where !owns(jeanne, item) {
            guard let garment = insert(item, state: .active, owner: jeanne) else { continue }
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
            Item(image: "sneakers-pink-small", category: .sneakers, color: .pink, size: 31),
            Item(image: "tights-brown-small", category: .tights, color: .brown, size: 128),
            Item(image: "tights-taupe-small", category: .tights, color: .beige, size: 128)
        ]
        for item in small where !owns(jeanne, item) {
            insert(item, state: .active, owner: jeanne)
        }
        return "Prêt : ouvrez Grandir › Jeanne."
    }

    private func sibling() -> String {
        let jeanne = preparedJeanne()
        let leon = child(named: "Léon") ?? {
            let created = Child(name: "Léon", ageInMonths: 52)
            context.insert(created)
            addGrowth(to: created, daysAgo: 30, height: 104.5, shoe: 26)
            return created
        }()
        let own: [Item] = [
            Item(image: "leon-hoodie-sage", category: .sweater, color: .green, size: 104),
            Item(image: "leon-overalls-denim", category: .overalls, color: .denim, size: 104),
            Item(image: "leon-chino-khaki", category: .pants, color: .beige, size: 104),
            Item(image: "leon-jacket-corduroy", category: .lightJacket, color: .orange, size: 104),
            Item(image: "leon-vest-quilted", category: .cardigan, color: .green, size: 104),
            Item(image: "leon-joggers-blue", category: .pants, color: .blue, size: 104, occasion: .sport),
            Item(image: "leon-longsleeve-dino", category: .longSleeve, color: .white, size: 104),
            Item(image: "leon-pajamas-stars", category: .pajamas, color: .navy, size: 104),
            Item(image: "leon-mariniere", category: .longSleeve, color: .navy, size: 104),
            Item(image: "leon-sweat-zip-sage", category: .sweater, color: .green, size: 110),
            Item(image: "leon-shirt-oxford", category: .longSleeve, color: .blue, size: 104, occasion: .dressy),
            Item(image: "leon-jacket-work", category: .lightJacket, color: .beige, size: 104),
            Item(image: "leon-cargo-beige", category: .pants, color: .beige, size: 110),
            Item(image: "leon-sweat-dino", category: .sweater, color: .grey, size: 104),
            Item(image: "leon-shorts-navy", category: .shorts, color: .navy, size: 104),
            Item(image: "leon-raincoat-sage", category: .raincoat, color: .green, size: 104),
            Item(image: "leon-beanie-stripes", category: .coldAccessory, color: .navy, size: 104),
            Item(image: "leon-bomber-khaki", category: .lightJacket, color: .green, size: 110),
            Item(image: "leon-henley-rust", category: .tshirt, color: .orange, size: 104),
            Item(image: "leon-pants-corduroy-green", category: .pants, color: .green, size: 104),
            Item(image: "leon-sweat-bear", category: .sweater, color: .beige, size: 104),
            Item(image: "leon-shirt-check", category: .longSleeve, color: .multicolor, size: 104),
            Item(image: "leon-puffer-grey", category: .coat, color: .grey, size: 110),
            Item(image: "leon-cardigan-mustard", category: .cardigan, color: .yellow, size: 104),
            Item(image: "leon-pants-tech-green", category: .pants, color: .green, size: 110, occasion: .sport),
            Item(image: "leon-overshirt-navy", category: .lightJacket, color: .navy, size: 104)
        ]
        for item in own where !owns(leon, item) {
            insert(item, state: .active, owner: leon)
        }
        // Jeanne's old clothes, waiting in the family boxes: they fit Léon now.
        let boxes: [Item] = [
            Item(image: "leon-sweater-stripes", category: .sweater, color: .white, size: 110),
            Item(image: "leon-raincoat-yellow", category: .raincoat, color: .yellow, size: 110),
            Item(image: "leon-jeans", category: .pants, color: .denim, size: 110),
            Item(image: "leon-vest-fleece", category: .cardigan, color: .white, size: 110)
        ]
        let stored = ((try? context.fetch(FetchDescriptor<Garment>())) ?? []).filter { $0.state == .stored }
        for item in boxes where !stored.contains(where: { $0.photo == photo(of: item) }) {
            insert(item, state: .stored, owner: nil)?.lastOwnerID = jeanne.id
        }
        let waiting = ((try? context.fetch(FetchDescriptor<Garment>())) ?? []).filter { $0.state == .stored }.count
        return "Prêt : Léon a \(leon.garments?.count ?? 0) vêtements, \(waiting) l'attendent dans les cartons."
    }

    private func event() -> String {
        let jeanne = preparedJeanne()
        let date = calendar.startOfDay(for: .now.addingTimeInterval(3 * day))
        let chosen = pieces(of: jeanne, [
            (.onePiece, .dress, .pink), (.legwear, .tights, .grey), (.layer, .cardigan, .white),
            (.outerwear, .lightJacket, .denim), (.shoes, .sneakers, .white)
        ])
        guard isComplete(chosen) else { return "En attente des photos : il faut au moins un haut et un bas." }
        let plan = replacePlan(for: jeanne, on: date)
        plan.context = .celebration
        plan.note = "Anniversaire de Lina"
        plan.piecesRaw = chosen.map(\.rawValue)
        return "Prêt : \(Formatting.longDate(date)), dans le carnet."
    }

    /// Every day of the month so far, for each child: the calendar fills with their colours.
    private func journal() -> String {
        let jeanne = preparedJeanne()
        _ = sibling()
        let children = [jeanne] + [child(named: "Léon")].compactMap { $0 }
        let today = calendar.startOfDay(for: .now)
        let monthStart = calendar.dateInterval(of: .month, for: today)?.start ?? today
        let days = calendar.dateComponents([.day], from: monthStart, to: today).day ?? 0
        let photo = resource("DemoOutfitPhoto", "jpg")
        var saved = 0
        for child in children {
            for index in 0..<days {
                guard let date = calendar.date(byAdding: .day, value: index, to: monthStart) else { continue }
                let chosen = outfit(for: child, on: date, index: index)
                guard isComplete(chosen) else { continue }
                let plan = replacePlan(for: child, on: date)
                plan.context = calendar.isDateInWeekend(date) ? .outing : .school
                plan.piecesRaw = chosen.map(\.rawValue)
                plan.proposedRaw = plan.piecesRaw
                plan.confirmedAt = date.addingTimeInterval(8 * 3600)
                // Two days ago, Jeanne's outfit has its photo, once one is provided.
                if child === jeanne && index == days - 2 { plan.photo = photo }
                saved += 1
            }
        }
        return saved == 0 ? "En attente des photos de vêtements." : "Prêt : \(Formatting.count(saved, "tenue", "tenues")) depuis le 1er du mois."
    }

    /// A plausible outfit that changes every day: the child's garments taken in turn, a dress
    /// every fourth day when there is one, tights under a dress or a skirt.
    private func outfit(for child: Child, on date: Date, index: Int) -> [OutfitPiece] {
        let profile = child.profile
        let wearable = (child.garments ?? [])
            .filter { $0.state == .active && profile.fit(of: $0.item, on: date).isWearable }
            .sorted { $0.id.uuidString < $1.id.uuidString }
        func pick(_ slot: OutfitSlot, _ offset: Int) -> Garment? {
            let options = wearable.filter { $0.category.slot == slot }
            return options.isEmpty ? nil : options[(index + offset) % options.count]
        }
        var chosen: [(OutfitSlot, Garment)] = []
        if index % 4 == 3, let dress = pick(.onePiece, 0) {
            chosen.append((.onePiece, dress))
        } else if let top = pick(.top, 0), let bottom = pick(.bottom, index / 3) {
            chosen += [(.top, top), (.bottom, bottom)]
        }
        if chosen.contains(where: { $0.1.category == .dress || $0.1.category == .shorts }), let tights = pick(.legwear, index) {
            chosen.append((.legwear, tights))
        }
        if index % 2 == 0, let layer = pick(.layer, index / 2) { chosen.append((.layer, layer)) }
        if index % 3 == 0, let outerwear = pick(.outerwear, index / 3) { chosen.append((.outerwear, outerwear)) }
        if let shoes = pick(.shoes, index) { chosen.append((.shoes, shoes)) }
        return chosen.map { OutfitPiece(slot: $0.0, itemID: $0.1.id) }
    }

    private func resale() -> String {
        let jeanne = preparedJeanne()
        let items: [(Item, Condition)] = [
            (Item(image: "sneakers-leopard-sale", category: .sneakers, color: .multicolor, size: 31), .veryGood),
            (Item(image: "sneakers-gold-sale", category: .sneakers, color: .yellow, size: 32), .good)
        ]
        let listed = (try? context.fetch(FetchDescriptor<Garment>())) ?? []
        guard !listed.contains(where: { $0.state == .forSale }) else { return "Déjà en vente." }
        var listedNow = 0
        for (item, condition) in items {
            guard let garment = insert(item, state: .forSale, owner: nil) else { continue }
            garment.lastOwnerID = jeanne.id
            garment.condition = condition
            listedNow += 1
        }
        return listedNow == 0 ? "En attente des photos de vêtements." : "Prêt : \(listedNow) vêtement(s) de Jeanne en vente."
    }

    /// Photos on a light table, like a parent would take them, for the batch add from the library.
    private func photos() -> String {
        let urls = (Bundle.main.urls(forResourcesWithExtension: "png", subdirectory: nil) ?? [])
            .filter { $0.lastPathComponent.hasPrefix("DemoGarment-") }
        var saved = 0
        for url in urls {
            guard let data = try? Data(contentsOf: url), let garment = UIImage(data: data) else { continue }
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

    /// Recognised by its photo, so two garments of the same kind, colour and size stay distinct.
    private func owns(_ child: Child, _ item: Item) -> Bool {
        let picture = photo(of: item)
        return (child.garments ?? []).contains { $0.photo == picture }
    }

    private func photo(of item: Item) -> Data? {
        resource("DemoGarment-\(item.image)", "png")
    }

    private func addGrowth(to child: Child, daysAgo: Double, height: Double, shoe: Double) {
        let entry = GrowthEntry(date: .now.addingTimeInterval(-daysAgo * day), heightCM: height, shoeSize: shoe, isApproximate: false)
        context.insert(entry)
        entry.child = child
    }

    /// Only garments with a real photo are created: the screenshots must look like the App Store page.
    @discardableResult
    private func insert(_ item: Item, state: LifecycleState, owner: Child?) -> Garment? {
        guard let picture = photo(of: item) else { return nil }
        let garment = Garment(
            photo: picture, category: item.category, color: item.color,
            size: item.size, occasion: item.occasion, brand: "", state: state
        )
        context.insert(garment)
        garment.owner = owner
        return garment
    }

    /// Worth showing: a dress or a matching set, or at least a top and a bottom.
    private func isComplete(_ pieces: [OutfitPiece]) -> Bool {
        let slots = Set(pieces.map(\.slot))
        return slots.contains(.onePiece) || (slots.contains(.top) && slots.contains(.bottom))
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
