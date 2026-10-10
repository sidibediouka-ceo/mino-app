import Foundation

/// Builds the outfit of the day from what fits, the weather, the day's context and the
/// family's habits. It does not chase style: it aims for the outfit a calm parent would pick.
public struct OutfitEngine {
    private let calendar: Calendar

    public init(calendar: Calendar) {
        self.calendar = calendar
    }

    private struct Candidate {
        let item: WardrobeItem
        let score: Double
    }

    public func propose(child: ChildProfile, items: [WardrobeItem], weather: DayForecast, context: DayContext) -> Outfit {
        let rank = { (slot: OutfitSlot) in candidates(for: slot, child: child, items: items, weather: weather, context: context) }
        let thermal = weather.thermal
        var chosen: [Candidate] = []
        var pieces: [OutfitPiece] = []
        var gaps: [OutfitSlot] = []

        let tops = rank(.top), bottoms = rank(.bottom), onePieces = rank(.onePiece)
        var bestCombo: (top: Candidate, bottom: Candidate, score: Double)?
        for top in tops.prefix(5) {
            for bottom in bottoms.prefix(5) {
                let score = top.score + bottom.score + GarmentColor.harmony(top.item.color, bottom.item.color)
                if score > bestCombo?.score ?? -.infinity { bestCombo = (top, bottom, score) }
            }
        }
        let onePieceScore = onePieces.first.map { $0.score * 2 - 0.5 + (context == .celebration ? 1 : 0) }
        if let onePiece = onePieces.first, let onePieceScore, onePieceScore > bestCombo?.score ?? -.infinity {
            chosen.append(onePiece)
            pieces.append(OutfitPiece(slot: .onePiece, itemID: onePiece.item.id))
        } else if let bestCombo {
            chosen += [bestCombo.top, bestCombo.bottom]
            pieces += [OutfitPiece(slot: .top, itemID: bestCombo.top.item.id), OutfitPiece(slot: .bottom, itemID: bestCombo.bottom.item.id)]
        } else {
            for (slot, ranked) in [(OutfitSlot.top, tops), (.bottom, bottoms)] {
                if let best = ranked.first {
                    chosen.append(best)
                    pieces.append(OutfitPiece(slot: slot, itemID: best.item.id))
                } else {
                    gaps.append(slot)
                }
            }
        }

        // Under a dress: a body for a baby whatever the weather (long-sleeved when cool), and a
        // long-sleeved top for an older child on a cool day.
        if chosen.contains(where: { $0.item.category == .dress }) {
            let tops = rank(.top)
            let isBaby = child.ageInMonths(at: weather.date) < 36
            let bodysuit = isBaby ? tops.first { $0.item.category.isBodysuit && (thermal > .cool || $0.item.category == .longSleeveBodysuit) } : nil
            let warm = thermal <= .cool ? tops.first { $0.item.category != .tshirt && $0.item.category != .bodysuit } : nil
            let anyBodysuit = isBaby ? tops.first { $0.item.category.isBodysuit } : nil
            if let under = bodysuit ?? warm ?? anyBodysuit {
                chosen.append(under)
                pieces.append(OutfitPiece(slot: .top, itemID: under.item.id))
            }
        }

        // Bare legs under a dress or a short on a cool day: add a collant if there is one.
        if thermal <= .cool, chosen.contains(where: { $0.item.category == .dress || $0.item.category == .shorts }),
           let tights = rank(.legwear).first {
            chosen.append(tights)
            pieces.append(OutfitPiece(slot: .legwear, itemID: tights.item.id))
        }

        if thermal <= .cool {
            let baseColor = chosen.first?.item.color
            let layers = rank(.layer).map { candidate in
                Candidate(item: candidate.item, score: candidate.score + 0.5 * (baseColor.map { GarmentColor.harmony($0, candidate.item.color) } ?? 0))
            }.sorted { $0.score > $1.score }
            if let layer = layers.first {
                chosen.append(layer)
                pieces.append(OutfitPiece(slot: .layer, itemID: layer.item.id))
            } else if thermal <= .cold {
                gaps.append(.layer)
            }
        }

        if context != .home {
            var outdoorSlots: [(slot: OutfitSlot, isGapWhenMissing: Bool)] = [(.shoes, true)]
            if thermal <= .cool || weather.isRainy { outdoorSlots.append((.outerwear, thermal <= .cold || weather.isRainy)) }
            if thermal == .freezing { outdoorSlots.append((.accessory, false)) }
            for (slot, isGapWhenMissing) in outdoorSlots {
                if let best = rank(slot).first {
                    chosen.append(best)
                    pieces.append(OutfitPiece(slot: slot, itemID: best.item.id))
                } else if isGapWhenMissing {
                    gaps.append(slot)
                }
            }
        }

        return Outfit(pieces: pieces, gaps: gaps, reasons: reasons(weather: weather, context: context, chosen: chosen.map(\.item)))
    }

    /// Other suitable garments for the slot of `itemID`, best first, excluding every piece
    /// already in the outfit.
    public func alternatives(
        to itemID: UUID, in outfit: Outfit,
        child: ChildProfile, items: [WardrobeItem], weather: DayForecast, context: DayContext
    ) -> [UUID] {
        guard let slot = outfit.pieces.first(where: { $0.itemID == itemID })?.slot else { return [] }
        let worn = Set(outfit.pieces.map(\.itemID))
        return candidates(for: slot, child: child, items: items, weather: weather, context: context)
            .map(\.item.id)
            .filter { !worn.contains($0) }
    }

    // MARK: Scoring

    private func candidates(
        for slot: OutfitSlot, child: ChildProfile, items: [WardrobeItem], weather: DayForecast, context: DayContext
    ) -> [Candidate] {
        let day = calendar.startOfDay(for: weather.date)
        return items.compactMap { item -> Candidate? in
            guard item.ownerID == child.id, item.state == .active, item.category.slot == slot,
                  !(context == .sport && item.category == .dress),
                  let suitability = Self.suitability(of: item.category, for: weather) else { return nil }
            let fit = child.fit(of: item, on: weather.date)
            guard fit.isWearable else { return nil }
            var score = suitability + context.occasionScore(item.occasion) + item.affinity
            if fit == .roomy { score -= 0.8 }
            if item.category.rotates { score += recencyScore(lastWornAt: item.lastWornAt, day: day) }
            score += Self.jitter(item.id, day: day)
            return Candidate(item: item, score: score)
        }
        .sorted { $0.score > $1.score }
    }

    private func recencyScore(lastWornAt: Date?, day: Date) -> Double {
        guard let lastWornAt else { return 0.3 }
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: lastWornAt), to: day).day ?? 0
        switch days {
        case ...1: return -3
        case 2: return -1.5
        case 3...4: return -0.5
        case 5...6: return 0
        default: return 0.5
        }
    }

    /// How appropriate a category is for the weather; `nil` means not at all.
    static func suitability(of category: GarmentCategory, for weather: DayForecast) -> Double? {
        let rainy = weather.isRainy
        switch (category, weather.thermal) {
        case (.tshirt, .hot), (.tshirt, .warm): return 2
        case (.tshirt, .mild): return 1
        case (.tshirt, .cool): return 0.2
        case (.bodysuit, .hot), (.bodysuit, .warm): return 2
        case (.bodysuit, .mild): return 1.2
        case (.bodysuit, .cool): return 0.4
        case (.longSleeveBodysuit, .freezing), (.longSleeveBodysuit, .cold), (.longSleeveBodysuit, .cool): return 2
        case (.longSleeveBodysuit, .mild): return 1.2
        case (.longSleeve, .freezing), (.longSleeve, .cold), (.longSleeve, .cool): return 2
        case (.longSleeve, .mild): return 1
        case (.turtleneck, .freezing): return 2.6
        case (.turtleneck, .cold): return 2.2
        case (.turtleneck, .cool): return 1.2
        case (.sweater, .freezing), (.sweater, .cold), (.sweater, .cool): return 2
        case (.cardigan, .freezing): return 1.4
        case (.cardigan, .cold): return 1.8
        case (.cardigan, .cool): return 2.2
        case (.dress, .hot), (.dress, .warm): return 2
        case (.dress, .mild): return 1.5
        case (.dress, .cool): return 0.5
        case (.playsuit, .freezing): return 0.5
        case (.playsuit, .cold), (.playsuit, .hot): return 1
        case (.playsuit, _): return 1.5
        case (.pants, .freezing), (.pants, .cold), (.pants, .cool): return 2
        case (.pants, .mild): return 1.5
        case (.pants, .warm): return 0
        case (.overalls, .freezing), (.overalls, .cold), (.overalls, .cool): return 2
        case (.overalls, .mild): return 1.5
        case (.tights, .freezing), (.tights, .cold): return 2
        case (.tights, .cool): return 1.5
        case (.shorts, .hot), (.shorts, .warm): return 2
        case (.shorts, .mild): return 0.3
        case (.lightJacket, .cool): return rainy ? 1 : 2
        case (.lightJacket, .mild): return 1
        case (.lightJacket, .cold): return 0
        case (.coat, .freezing): return 2.5
        case (.coat, .cold): return rainy ? 1.5 : 2
        case (.coat, .cool): return 0
        case (.raincoat, .freezing): return rainy ? 0.5 : nil
        case (.raincoat, .cold): return rainy ? 1.8 : nil
        case (.raincoat, _): return rainy ? 2.5 : (weather.thermal == .cool ? 1 : nil)
        case (.sneakers, .freezing): return rainy ? -0.5 : 0.5
        case (.sneakers, .hot): return 1
        case (.sneakers, _): return rainy ? 1 : 2
        case (.boots, .freezing): return 2.5
        case (.boots, .cold): return rainy ? 2.5 : 1.5
        case (.boots, _): return rainy ? 2.5 : nil
        case (.sandals, .hot): return rainy ? nil : 2.5
        case (.sandals, .warm): return rainy ? nil : 2
        case (.coldAccessory, .freezing): return 2
        case (.coldAccessory, .cold): return 1
        default: return nil
        }
    }

    /// A small, stable per-day variation so that equally good garments take turns.
    private static func jitter(_ id: UUID, day: Date) -> Double {
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in "\(id.uuidString)\(Int(day.timeIntervalSince1970 / 86_400))".utf8 {
            hash = (hash ^ UInt64(byte)) &* 0x0000_0100_0000_01b3
        }
        return Double(hash % 1000) / 1000 * 0.3
    }

    // MARK: Explanations

    /// Temperatures are shown once, above all outfits; reasons explain the choice instead.
    private func reasons(weather: DayForecast, context: DayContext, chosen: [WardrobeItem]) -> [String] {
        let feel: String
        switch weather.thermal {
        case .freezing: feel = "Très froid"
        case .cold: feel = "Frais"
        case .cool: feel = "Fraîcheur le matin"
        case .mild: feel = "Temps doux"
        case .warm: feel = "Belle journée"
        case .hot: feel = "Chaud"
        }
        let warmth = chosen
            .filter { [.turtleneck, .tights, .sweater, .cardigan, .lightJacket, .coat, .coldAccessory].contains($0.category) }
            .map(\.category.definiteName)
        let light = weather.thermal >= .mild ? "une tenue légère" : "une tenue simple"
        var reasons = ["\(feel) : \(warmth.isEmpty ? light : Self.list(warmth))"]

        if weather.isRainy {
            let gear = chosen.filter { $0.category == .raincoat || $0.category == .boots }.map(\.category.definiteName)
            reasons.append(gear.isEmpty ? "Pluie prévue" : "Pluie prévue : \(Self.list(gear))")
        }

        switch context {
        case .sport: reasons.append("Jour de sport : tenue souple et baskets")
        case .celebration: reasons.append("Jour de fête : place à la tenue habillée")
        case .home: reasons.append("Journée à la maison : le confort d'abord")
        case .school, .outing: break
        }

        let day = calendar.startOfDay(for: weather.date)
        let daysSinceWorn = { (item: WardrobeItem) -> Int? in
            item.lastWornAt.flatMap { calendar.dateComponents([.day], from: calendar.startOfDay(for: $0), to: day).day }
        }
        if let forgotten = chosen.first(where: { $0.category.rotates && (daysSinceWorn($0) ?? 0) >= 14 }),
           let days = daysSinceWorn(forgotten) {
            let agreement = forgotten.category.isFeminine ? "portée" : "porté"
            let name = forgotten.category.definiteName
            reasons.append("\(name.prefix(1).uppercased() + name.dropFirst()) n'a pas été \(agreement) depuis \(days) jours")
        }
        return Array(reasons.prefix(2))
    }

    /// "a", "a et b", "a, b et c".
    private static func list(_ words: [String]) -> String {
        guard let last = words.last else { return "" }
        return words.count == 1 ? last : words.dropLast().joined(separator: ", ") + " et " + last
    }
}
