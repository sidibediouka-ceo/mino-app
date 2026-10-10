import SwiftUI

/// First use in under 90 seconds: a promise, a child, a few photos.
struct OnboardingView: View {
    let onFinish: () -> Void

    private enum Step {
        case welcome
        case child
        case garments(Child)
    }

    @State private var step: Step = .welcome

    var body: some View {
        NavigationStack {
            Group {
                switch step {
                case .welcome:
                    WelcomeView { step = .child }
                case .child:
                    ChildFormView(mode: .create) { child in step = .garments(child) }
                        .navigationTitle("Votre enfant")
                case .garments(let child):
                    AddGarmentsView(owner: child, sizing: child.profile, onFinish: onFinish)
                        .navigationTitle("La garde-robe de \(child.name)")
                }
            }
            .background(Theme.background)
        }
    }
}

private struct WelcomeView: View {
    let onStart: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Mino")
                        .font(.system(size: 44, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.forest)
                    Text("La garde-robe de vos enfants, qui grandit avec eux.")
                        .font(.title3)
                        .foregroundStyle(Theme.secondaryText)
                }
                .padding(.top, 40)

                VStack(alignment: .leading, spacing: 22) {
                    Promise(symbol: "moon.stars", title: "Chaque soir, demain est prêt",
                            message: "La tenue adaptée à la météo et à la journée, en un coup d'œil.")
                    Promise(symbol: "chart.line.uptrend.xyaxis", title: "Chaque saison, rien ne manque",
                            message: "Mino anticipe la taille d'après et regarde d'abord dans vos cartons.")
                    Promise(symbol: "arrow.triangle.2.circlepath", title: "Chaque vêtement a une seconde vie",
                            message: "Transmettre, donner ou vendre, en un geste.")
                    Promise(symbol: "lock", title: "Tout reste sur votre iPhone",
                            message: "Pas de compte, pas de publicité, pas de suivi.")
                }
            }
            .padding(24)
        }
        .safeAreaInset(edge: .bottom) {
            Button("Commencer", action: onStart)
                .buttonStyle(PrimaryButtonStyle())
                .padding(24)
        }
    }
}

private struct Promise: View {
    let symbol: String
    let title: String
    let message: String

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: symbol)
                .font(.title2)
                .foregroundStyle(Theme.sage)
                .frame(width: 32)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline).foregroundStyle(Theme.forest)
                Text(message).font(.subheadline).foregroundStyle(Theme.secondaryText)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
