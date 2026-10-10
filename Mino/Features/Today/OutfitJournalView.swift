import MinoKit
import SwiftData
import SwiftUI

/// "Carnet des tenues": a private calendar of what each child wore, with the photo of the moment
/// when the parent took one, and the place to prepare an outfit ahead for a special day. On the
/// day, the home screen shows the prepared outfit. Nothing leaves the iPhone.
struct OutfitJournalView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(sort: \Child.createdAt) private var children: [Child]
    @Query private var garments: [Garment]
    @Query(sort: \PlannedOutfit.day) private var plans: [PlannedOutfit]
    @State private var selectedDay = Date.now
    @State private var composing: Composition?
    @State private var viewing: ViewedPhoto?

    private let calendar = Calendar.current

    private struct Composition: Identifiable {
        let id = UUID()
        let child: Child
        let plan: PlannedOutfit?
    }

    private struct ViewedPhoto: Identifiable {
        let id = UUID()
        let image: UIImage
    }

    var body: some View {
        let family = FamilySnapshot(children: children, garments: garments)
        let today = calendar.startOfDay(for: .now)
        let lastDay = calendar.date(byAdding: .year, value: 1, to: today) ?? today
        let isPast = calendar.startOfDay(for: selectedDay) < today
        let isFuture = calendar.startOfDay(for: selectedDay) > today
        let dayPlans = plans.filter { calendar.isDate($0.day, inSameDayAs: selectedDay) }

        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    DatePicker("Jour", selection: $selectedDay, in: ...lastDay, displayedComponents: .date)
                        .datePickerStyle(.graphical)
                        .environment(\.locale, Locale(identifier: "fr_FR"))
                        .tint(Theme.accent)
                        .minoCard(padding: 8)

                    Text(Formatting.longDate(selectedDay))
                        .font(.system(.title3, design: .rounded).weight(.bold))
                        .foregroundStyle(Theme.ink)

                    if isPast && dayPlans.isEmpty {
                        EmptyStateView(
                            symbol: "calendar",
                            title: "Pas de tenue ce jour-là",
                            message: "Le carnet se remplit tout seul, jour après jour, avec les tenues portées."
                        )
                    }

                    ForEach(children) { child in
                        let plan = dayPlans.first { $0.child?.id == child.id }
                        if let plan {
                            JournalEntry(
                                child: child, color: children.color(of: child), plan: plan, family: family,
                                isEditable: !isPast, canAddPhoto: !isFuture,
                                onEdit: { composing = Composition(child: child, plan: plan) },
                                onRemove: { context.delete(plan) },
                                onPhoto: { attach($0, to: plan, family: family) },
                                onShowPhoto: { viewing = ViewedPhoto(image: $0) }
                            )
                        } else if isPast {
                            OutfitPhotoMenu(onImage: { addPhotoOnly($0, for: child) }) {
                                photoOnlyLabel(for: child)
                            }
                        } else {
                            Button {
                                composing = Composition(child: child, plan: nil)
                            } label: {
                                HStack(spacing: 12) {
                                    ChildAvatar(name: child.name, color: children.color(of: child), size: 32)
                                    Text("Préparer la tenue de \(child.name)")
                                        .font(.system(.headline, design: .rounded))
                                        .foregroundStyle(Theme.ink)
                                    Spacer()
                                    Image(systemName: "plus.circle.fill")
                                        .font(.title3)
                                        .foregroundStyle(children.color(of: child))
                                }
                                .minoCard(padding: 14)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(20)
            }
            .background(Theme.background)
            .navigationTitle("Carnet des tenues")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("OK") { dismiss() }
                }
            }
            .sheet(item: $composing) { composition in
                OutfitComposerView(child: composition.child, day: selectedDay, existing: composition.plan)
            }
            .fullScreenCover(item: $viewing) { OutfitPhotoViewer(image: $0.image) }
        }
    }

    private func photoOnlyLabel(for child: Child) -> some View {
        HStack(spacing: 12) {
            ChildAvatar(name: child.name, color: children.color(of: child), size: 32)
            Text("Ajouter la photo de la tenue de \(child.name)")
                .font(.system(.headline, design: .rounded))
                .foregroundStyle(Theme.ink)
                .multilineTextAlignment(.leading)
            Spacer()
            Image(systemName: "camera.fill")
                .font(.title3)
                .foregroundStyle(children.color(of: child))
        }
        .minoCard(padding: 14)
    }

    /// A photo means the outfit was worn: it is recorded as such (rotation, learning).
    private func attach(_ image: UIImage, to plan: PlannedOutfit, family: FamilySnapshot) {
        plan.photo = OutfitPhoto.storedData(for: image)
        if plan.confirmedAt == nil {
            DayPlanner(family: family, context: context, calendar: calendar).confirm(plan)
        }
    }

    /// A day without a recorded outfit keeps just the photo.
    private func addPhotoOnly(_ image: UIImage, for child: Child) {
        let plan = PlannedOutfit(day: calendar.startOfDay(for: selectedDay))
        context.insert(plan)
        plan.child = child
        plan.context = child.routine.context(on: selectedDay, calendar: calendar)
        plan.photo = OutfitPhoto.storedData(for: image)
        plan.confirmedAt = .now
    }
}

private struct JournalEntry: View {
    let child: Child
    let color: Color
    let plan: PlannedOutfit
    let family: FamilySnapshot
    let isEditable: Bool
    /// Today and past days: the outfit can be immortalised.
    let canAddPhoto: Bool
    let onEdit: () -> Void
    let onRemove: () -> Void
    let onPhoto: (UIImage) -> Void
    let onShowPhoto: (UIImage) -> Void

    private var photo: UIImage? { plan.photo.flatMap(UIImage.init(data:)) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                ChildAvatar(name: child.name, color: color, size: 32)
                VStack(alignment: .leading, spacing: 2) {
                    Text(child.name)
                        .font(.system(.headline, design: .rounded))
                        .foregroundStyle(Theme.ink)
                    Text(status)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.secondaryText)
                }
                Spacer()
                if isEditable || photo != nil {
                    Menu {
                        if isEditable {
                            Button("Modifier la tenue", systemImage: "pencil", action: onEdit)
                            Button(role: .destructive, action: onRemove) {
                                Label(
                                    plan.isPreparedByParent ? "Retirer cette tenue" : "Laisser Mino la refaire",
                                    systemImage: "arrow.uturn.backward"
                                )
                            }
                        }
                        if photo != nil {
                            Button(role: .destructive) { plan.photo = nil } label: {
                                Label("Retirer la photo", systemImage: "photo.badge.minus")
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.title3)
                            .foregroundStyle(Theme.ink)
                    }
                    .accessibilityLabel("Options de la tenue de \(child.name)")
                }
            }
            if !plan.note.isEmpty {
                Label(plan.note, systemImage: "calendar.badge.checkmark")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(color)
            }
            if let photo {
                HStack(alignment: .top, spacing: 12) {
                    Button { onShowPhoto(photo) } label: {
                        Image(uiImage: photo)
                            .resizable()
                            .scaledToFill()
                            .frame(width: plan.outfit.pieces.isEmpty ? nil : 120, height: plan.outfit.pieces.isEmpty ? 280 : 170)
                            .frame(maxWidth: plan.outfit.pieces.isEmpty ? .infinity : nil)
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                            .overlay(alignment: .bottomTrailing) {
                                Image(systemName: "arrow.up.left.and.arrow.down.right")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(.white)
                                    .padding(6)
                                    .background(.black.opacity(0.35), in: Circle())
                                    .padding(6)
                            }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Photo de la tenue de \(child.name), toucher pour agrandir")
                    if !plan.outfit.pieces.isEmpty {
                        OutfitBoard(pieces: plan.outfit.pieces, family: family)
                    }
                }
            } else {
                OutfitBoard(pieces: plan.outfit.pieces, family: family)
                if canAddPhoto {
                    OutfitPhotoMenu(onImage: onPhoto) {
                        Label("Immortaliser la tenue", systemImage: "camera.fill")
                            .font(.system(.subheadline, design: .rounded).weight(.semibold))
                            .padding(.vertical, 10)
                            .padding(.horizontal, 16)
                            .foregroundStyle(Theme.ink)
                            .background(Theme.card, in: Capsule())
                    }
                }
            }
        }
        .padding(16)
        .background(color.opacity(0.13), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var status: String {
        let kind = plan.confirmedAt != nil || plan.photo != nil
            ? "Portée"
            : (plan.isPreparedByParent ? "Préparée par vous" : "Proposée par Mino")
        return "\(kind) · \(plan.context.displayName)"
    }
}
