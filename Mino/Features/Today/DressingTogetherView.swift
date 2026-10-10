import SwiftUI

/// "Mode enfant", inspired by Japanese nurseries: the child sees each piece in big, in the order
/// they put it on, and ticks it off. Getting dressed becomes their own little achievement.
struct DressingTogetherView: View {
    let childName: String
    let color: Color
    let garments: [Garment]
    let onFinish: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var done: Set<UUID> = []

    private var isFinished: Bool { !garments.isEmpty && done.count == garments.count }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            VStack(spacing: 20) {
                HStack {
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title)
                            .foregroundStyle(Theme.secondaryText)
                    }
                    .accessibilityLabel("Fermer")
                }

                VStack(spacing: 8) {
                    Image(systemName: isFinished ? "star.fill" : "sparkles")
                        .font(.system(size: 44))
                        .foregroundStyle(color)
                        .symbolEffect(.bounce, value: isFinished)
                    Text(isFinished ? "Bravo \(childName) !" : "À toi, \(childName) !")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.ink)
                        .multilineTextAlignment(.center)
                }

                ScrollView {
                    VStack(spacing: 14) {
                        ForEach(garments, id: \.id) { garment in
                            let isDone = done.contains(garment.id)
                            Button { toggle(garment.id) } label: {
                                HStack(spacing: 20) {
                                    GarmentImage(photo: garment.photo)
                                        .frame(width: 120, height: 120)
                                    Spacer()
                                    Image(systemName: isDone ? "checkmark.circle.fill" : "circle")
                                        .font(.system(size: 48))
                                        .foregroundStyle(isDone ? color : Theme.secondaryText.opacity(0.5))
                                }
                                .minoCard(padding: 12)
                                .opacity(isDone ? 0.6 : 1)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(garment.category.displayName)
                            .accessibilityValue(isDone ? "Mis" : "À mettre")
                        }
                    }
                }

                if isFinished {
                    Button("C'est parti !") {
                        onFinish()
                        dismiss()
                    }
                    .buttonStyle(PrimaryButtonStyle(color: color))
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(24)
        }
        .animation(.spring(duration: 0.35), value: done)
        .sensoryFeedback(.impact(weight: .light), trigger: done.count)
    }

    private func toggle(_ id: UUID) {
        if done.contains(id) { done.remove(id) } else { done.insert(id) }
    }
}
