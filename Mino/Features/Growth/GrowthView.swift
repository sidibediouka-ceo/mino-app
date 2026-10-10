import MinoKit
import SwiftData
import SwiftUI

/// "Grandir": the tab of passages. Moving into the next size and the big seasonal switch are
/// the two moments that reshape a wardrobe; Mino prepares each one in three gestures, and
/// keeps quiet in between. The toise keeps the memory of the child growing.
struct GrowthView: View {
    @Environment(\.modelContext) private var context
    @Environment(AppRouter.self) private var router
    @Query(sort: \Child.createdAt) private var children: [Child]
    @Query private var garments: [Garment]
    @Query private var covered: [CoveredNeed]
    @State private var selectedID: UUID?
    @State private var measuring: Child?
    @State private var adding: Child?
    @State private var editing: Child?
    @State private var sortBatch: SortBatch?
    @State private var handMeDown: HandMeDownRequest?

    private var selected: Child? {
        children.first { $0.id == selectedID } ?? children.first
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if children.count > 1, let selected {
                        ChipPicker(options: children.map(\.id), selection: Binding(get: { selected.id }, set: { selectedID = $0 })) { id in
                            children.first { $0.id == id }?.name ?? ""
                        }
                    }
                    if let child = selected {
                        let family = FamilySnapshot(children: children, garments: garments)
                        let color = children.color(of: child)
                        if let plan = family.passagePlan(for: child, covered: covered, calendar: .current) {
                            PassageCard(
                                child: child, color: color, plan: plan, family: family,
                                onSort: { sortBatch = SortBatch(garments: $0, date: plan.passage.date) },
                                onTakeFromFamily: { handMeDown = HandMeDownRequest(child: child, date: plan.passage.date) },
                                onCovered: { context.insert(CoveredNeed(needID: $0.id)) },
                                onAddGarments: { adding = child }
                            )
                        }
                        ToiseCard(child: child, color: color) { measuring = child }
                    }
                }
                .padding(20)
            }
            .background(Theme.background)
            .navigationTitle("Grandir")
            .toolbar {
                if let selected {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Modifier") { editing = selected }
                            .accessibilityLabel("Modifier le profil de \(selected.name)")
                    }
                }
            }
            .sheet(item: $editing) { child in
                NavigationStack {
                    ChildFormView(mode: .edit(child)) { _ in editing = nil }
                        .navigationTitle(child.name)
                        .navigationBarTitleDisplayMode(.inline)
                }
            }
            .sheet(item: $measuring) { MeasureView(child: $0) }
            .sheet(item: $sortBatch) { SortSessionView(garments: $0.garments, children: children, date: $0.date) }
            .sheet(item: $handMeDown) { HandMeDownView(child: $0.child, date: $0.date) }
            .sheet(item: $adding) { child in
                NavigationStack {
                    AddGarmentsView(owner: child, sizing: child.profile) { adding = nil }
                        .navigationTitle("Pour \(child.name)")
                        .navigationBarTitleDisplayMode(.inline)
                }
            }
            .onChange(of: router.focusedChildID, initial: true) { _, id in
                if let id { selectedID = id }
            }
        }
    }
}

private struct HandMeDownRequest: Identifiable {
    let id = UUID()
    let child: Child
    let date: Date
}

// MARK: - Passage

/// The next passage. Calm while it is far away; three gestures when it comes near.
private struct PassageCard: View {
    let child: Child
    let color: Color
    let plan: PassagePlan
    let family: FamilySnapshot
    let onSort: ([Garment]) -> Void
    let onTakeFromFamily: () -> Void
    let onCovered: (Need) -> Void
    let onAddGarments: () -> Void

    private var passage: Passage { plan.passage }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Prochain passage")
                    .font(.system(.caption, design: .rounded).weight(.bold))
                    .textCase(.uppercase)
                    .foregroundStyle(color)
                Text(title)
                    .font(.system(.title2, design: .rounded).weight(.bold))
                    .foregroundStyle(Theme.ink)
                Text(window)
                    .font(.subheadline)
                    .foregroundStyle(Theme.secondaryText)
            }

            if !passage.isUnderway(on: .now) {
                Label("Rien à faire d'ici là. Quelques semaines avant, Mino vous aidera à le préparer.", systemImage: "leaf")
                    .font(.subheadline)
                    .foregroundStyle(Theme.ink)
            } else if !plan.knowsWardrobe {
                Text("Ajoutez quelques vêtements de \(child.name) : Mino pourra préparer ce passage avec vous.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.secondaryText)
                Button("Ajouter ses vêtements", systemImage: "camera.fill", action: onAddGarments)
                    .buttonStyle(PrimaryButtonStyle(color: color))
            } else {
                if plan.isReady {
                    Label(readyMessage, systemImage: "sparkles")
                        .font(.system(.headline, design: .rounded))
                        .foregroundStyle(color)
                }
                steps
            }
        }
        .padding(18)
        .background(color.opacity(0.13), in: RoundedRectangle(cornerRadius: 30, style: .continuous))
    }

    private var title: String {
        switch passage.kind {
        case .size(let size): return "\(child.name) passe en \(SizeChart.shortLabel(size: size, kind: .clothing))"
        case .season(.summer): return "Place à l'été"
        case .season: return "Place aux vêtements chauds"
        }
    }

    private var window: String {
        switch passage.kind {
        case .size: return Formatting.sentence(Formatting.window(passage.when))
        case .season: return "À partir du \(Formatting.shortDate(passage.date))"
        }
    }

    private var readyMessage: String {
        switch passage.kind {
        case .size(let size): return "Tout est prêt pour le passage en \(SizeChart.shortLabel(size: size, kind: .clothing))."
        case .season: return "Tout est prêt pour \(passage.season.displayName) de \(child.name)."
        }
    }

    // MARK: Steps

    private var steps: some View {
        let outgrown = plan.outgrown.compactMap(family.garment)
        let toFind = plan.toFind
        return VStack(alignment: .leading, spacing: 14) {
            StepRow(
                number: 1, color: color, title: "Trier ce qui devient petit",
                detail: outgrown.isEmpty ? "Rien à trier." : Formatting.count(outgrown.count, "vêtement deviendra petit", "vêtements deviendront petits"),
                isDone: outgrown.isEmpty
            ) {
                if !outgrown.isEmpty {
                    Button("Trier") { onSort(outgrown) }
                        .buttonStyle(SecondaryButtonStyle())
                }
            }
            StepRow(
                number: 2, color: color, title: "Reprendre de la famille",
                detail: plan.fromFamily.isEmpty
                    ? "Rien dans les cartons à sa taille pour l'instant."
                    : "\(Formatting.count(plan.fromFamily.count, "vêtement lui ira", "vêtements lui iront")) : inutile d'acheter.",
                isDone: plan.fromFamily.isEmpty
            ) {
                if !plan.fromFamily.isEmpty {
                    Button("Voir", action: onTakeFromFamily)
                        .buttonStyle(SecondaryButtonStyle())
                }
            }
            StepRow(
                number: 3, color: color, title: "Compléter",
                detail: toFind.isEmpty ? "Rien à trouver." : "Peut-être à prévoir, si vous ne l'avez pas déjà :",
                isDone: toFind.isEmpty
            ) {
                if !toFind.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(toFind) { need in
                            HStack {
                                Text("\(need.group.displayName) · \(need.stillMissing) en \(SizeChart.shortLabel(size: need.size, kind: need.group.sizeKind))")
                                    .font(.subheadline)
                                    .foregroundStyle(Theme.ink)
                                Spacer()
                                Button("J'en ai assez") { onCovered(need) }
                                    .font(.footnote.weight(.semibold))
                                    .foregroundStyle(Theme.accent)
                            }
                        }
                        ShareLink(item: ShoppingList.text(for: child.name, needs: toFind)) {
                            Label("Partager ma liste", systemImage: "square.and.arrow.up")
                        }
                        .buttonStyle(SecondaryButtonStyle())
                    }
                }
            }
        }
    }
}

private struct StepRow<Action: View>: View {
    let number: Int
    let color: Color
    let title: String
    let detail: String
    let isDone: Bool
    @ViewBuilder var action: Action

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle().fill(isDone ? color : Theme.card)
                if isDone {
                    Image(systemName: "checkmark").font(.caption.weight(.bold)).foregroundStyle(.white)
                } else {
                    Text("\(number)").font(.system(.subheadline, design: .rounded).weight(.bold)).foregroundStyle(color)
                }
            }
            .frame(width: 28, height: 28)
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.system(.headline, design: .rounded))
                    .foregroundStyle(Theme.ink)
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(Theme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                action
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Étape \(number), \(title), \(isDone ? "faite" : detail)")
    }
}

// MARK: - Toise

/// The pencil marks on the door frame: past measurements, today, and the next size ahead.
private struct ToiseCard: View {
    let child: Child
    let color: Color
    let onMeasure: () -> Void

    var body: some View {
        let profile = child.profile
        VStack(alignment: .leading, spacing: 14) {
            Text("La toise de \(child.name)")
                .font(.system(.title3, design: .rounded).weight(.bold))
                .foregroundStyle(Theme.ink)
            ToiseView(profile: profile, color: color)
            if let next = profile.nextSize(.shoes, after: .now) {
                Label("Pointure \(next.size) \(Formatting.window(next.when))", systemImage: "shoeprints.fill")
                    .font(.subheadline)
                    .foregroundStyle(Theme.ink)
            }
            HStack {
                Text(profile.lastMeasuredHeightDate.map { "Dernière mesure le \(Formatting.shortDate($0))." }
                     ?? "Estimée d'après ses vêtements.")
                    .font(.footnote)
                    .foregroundStyle(Theme.secondaryText)
                Spacer()
                Button("Mesurer", systemImage: "ruler", action: onMeasure)
                    .buttonStyle(SecondaryButtonStyle())
            }
        }
        .minoCard()
    }
}

private struct ToiseView: View {
    let profile: ChildProfile
    let color: Color

    private struct Mark: Identifiable {
        enum Kind { case past, today, ahead }
        let id = UUID()
        let height: Double
        let label: String
        let kind: Kind
    }

    private var marks: [Mark] {
        let now = Date.now
        let today = profile.height(at: now).expected
        var marks = profile.records
            .filter { $0.heightCM != nil && !$0.isApproximate }
            .suffix(3)
            .compactMap { record -> Mark? in
                guard let height = record.heightCM, abs(height - today) >= 1.5 else { return nil }
                return Mark(height: height, label: "\(Int(height.rounded())) cm · \(Formatting.shortDate(record.date))", kind: .past)
            }
        marks.append(Mark(height: today, label: "Aujourd'hui · environ \(Int(today.rounded())) cm", kind: .today))
        if let next = profile.nextSize(.clothing, after: now) {
            let threshold = Double(profile.currentSize(.clothing, on: now)) + 2
            marks.append(Mark(
                height: threshold,
                label: "\(SizeChart.shortLabel(size: next.size, kind: .clothing)) · vers \(Formatting.period(next.when.expected))",
                kind: .ahead
            ))
        }
        return marks
    }

    var body: some View {
        let marks = self.marks
        let heights = marks.map(\.height)
        let low = (heights.min() ?? 0) - 3
        let high = max((heights.max() ?? 0) + 3, low + 14)
        GeometryReader { geometry in
            let y = { (height: Double) in geometry.size.height * (1 - (height - low) / (high - low)) }
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(color.opacity(0.22))
                    .frame(width: 14)
                ForEach(marks) { mark in
                    HStack(spacing: 8) {
                        if mark.kind == .ahead {
                            Rectangle()
                                .stroke(color, style: StrokeStyle(lineWidth: 2, dash: [4, 3]))
                                .frame(width: 34, height: 1)
                        } else {
                            Capsule()
                                .fill(mark.kind == .today ? color : Theme.ink.opacity(0.5))
                                .frame(width: 34, height: mark.kind == .today ? 4 : 2)
                        }
                        Text(mark.label)
                            .font(.system(.footnote, design: .rounded).weight(mark.kind == .today ? .bold : .regular))
                            .foregroundStyle(mark.kind == .ahead ? color : Theme.ink)
                    }
                    .offset(y: y(mark.height) - 9)
                }
            }
        }
        .frame(height: 190)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(marks.map(\.label).joined(separator: ", "))
    }
}
