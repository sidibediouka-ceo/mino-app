import AVFoundation
import MinoKit
import SwiftUI

/// "Mode enfant", inspired by Japanese nurseries: handed to a child of about 3 to 8, it shows one
/// garment at a time, very large, in the order they put things on, and says what to put on.
/// The child taps it once it is on; it joins the basket. Nothing to read, and only a parent's
/// long press leaves the screen.
struct DressingTogetherView: View {
    let childName: String
    let color: Color
    /// In dressing order.
    let garments: [Garment]
    let onFinish: () -> Void

    @Environment(\.dismiss) private var dismiss
    @AppStorage("childModeVoice") private var voiceOn = true
    @State private var index = 0
    @State private var voice = Voice()
    @Namespace private var basket

    private var isFinished: Bool { index >= garments.count }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            color.opacity(0.16).ignoresSafeArea()
            VStack(spacing: 24) {
                controls
                Spacer(minLength: 0)
                if isFinished {
                    celebration
                } else {
                    current(garments[index])
                }
                Spacer(minLength: 0)
                basketRow
            }
            .padding(24)
        }
        .sensoryFeedback(.impact(weight: .medium), trigger: index)
        .onAppear(perform: speak)
        .onChange(of: index) { speak() }
        .onDisappear { voice.stop() }
        .task(id: isFinished) {
            guard isFinished else { return }
            try? await Task.sleep(for: .seconds(2.5))
            onFinish()
            dismiss()
        }
    }

    // MARK: Parts

    private var controls: some View {
        HStack {
            Button { voiceOn.toggle(); speak() } label: {
                Image(systemName: voiceOn ? "speaker.wave.2.fill" : "speaker.slash.fill")
                    .font(.title2)
                    .foregroundStyle(Theme.secondaryText)
            }
            .accessibilityLabel(voiceOn ? "Couper la voix" : "Activer la voix")
            Spacer()
            VStack(spacing: 2) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title)
                    .foregroundStyle(Theme.secondaryText)
                Text("Appui long")
                    .font(.caption2)
                    .foregroundStyle(Theme.secondaryText)
            }
            .onLongPressGesture(minimumDuration: 0.8) { dismiss() }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Quitter le mode enfant")
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { dismiss() }
        }
    }

    private func current(_ garment: Garment) -> some View {
        Button(action: next) {
            VStack(spacing: 28) {
                GarmentImage(photo: garment.photo)
                    .matchedGeometryEffect(id: garment.id, in: basket)
                    .frame(width: 280, height: 280)
                Image(systemName: "hand.tap.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(color)
                    .frame(width: 96, height: 96)
                    .background(Theme.card, in: Circle())
                    .shadow(color: color.opacity(0.3), radius: 12, y: 6)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(garment.category.childInstruction)
        .accessibilityHint("Touchez quand c'est mis")
    }

    private var celebration: some View {
        Image(systemName: "star.fill")
            .font(.system(size: 140))
            .foregroundStyle(color)
            .symbolEffect(.bounce, value: isFinished)
            .accessibilityLabel("Bravo \(childName) !")
    }

    /// What is already on: small tiles, and a dot for each piece still to come.
    private var basketRow: some View {
        HStack(spacing: 10) {
            ForEach(Array(garments.enumerated()), id: \.element.id) { position, garment in
                if position < index {
                    GarmentImage(photo: garment.photo)
                        .matchedGeometryEffect(id: garment.id, in: basket)
                        .frame(width: 52, height: 52)
                } else if position > index {
                    Circle()
                        .fill(color.opacity(0.35))
                        .frame(width: 14, height: 14)
                }
            }
        }
        .frame(height: 56)
        .accessibilityHidden(true)
    }

    // MARK: Actions

    private func next() {
        withAnimation(.spring(duration: 0.5)) { index += 1 }
    }

    private func speak() {
        guard voiceOn else { return voice.stop() }
        voice.say(isFinished ? "Bravo \(childName) !" : garments[index].category.childInstruction)
    }
}

/// Reads the instructions aloud on the device, in French.
private final class Voice {
    private let synthesizer = AVSpeechSynthesizer()

    func say(_ text: String) {
        synthesizer.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "fr-FR")
        utterance.rate = 0.45
        synthesizer.speak(utterance)
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
    }
}
