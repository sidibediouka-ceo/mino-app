import SwiftUI

struct BriefingContent {
    let symbol: String
    let title: String
    let message: String
    let action: String
}

/// One suggestion, one gesture.
struct BriefingCard: View {
    let content: BriefingContent
    let onAction: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: content.symbol)
                .font(.title3)
                .foregroundStyle(Theme.forest)
                .frame(width: 40, height: 40)
                .background(Theme.sage.opacity(0.22), in: Circle())
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 6) {
                Text(content.title)
                    .font(.headline)
                    .foregroundStyle(Theme.forest)
                Text(content.message)
                    .font(.subheadline)
                    .foregroundStyle(Theme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                Button(content.action, action: onAction)
                    .buttonStyle(SecondaryButtonStyle())
                    .padding(.top, 4)
            }
        }
        .minoCard()
    }
}
