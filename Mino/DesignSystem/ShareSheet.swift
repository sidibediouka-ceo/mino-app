import SwiftUI
import UIKit

/// What a listing shares: its text and the garments' photos, ready for any resale app.
struct ListingShare: Identifiable {
    let id = UUID()
    let text: String
    let photos: [UIImage]

    /// Background-free photos are laid on white, square, with a margin: transparent images show
    /// up black on most marketplaces.
    init(text: String, photos: [Data?]) {
        self.text = text
        self.photos = photos.compactMap { $0.flatMap(UIImage.init(data:)).map(Self.onWhite) }
    }

    private static func onWhite(_ image: UIImage) -> UIImage {
        let side = max(image.size.width, image.size.height) * 1.15
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: CGSize(width: side, height: side), format: format).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(x: 0, y: 0, width: side, height: side))
            image.draw(at: CGPoint(x: (side - image.size.width) / 2, y: (side - image.size.height) / 2))
        }
    }
}

/// The system share sheet with photos and text: save the images to Photos, send them, or open
/// them in a resale app.
struct ShareSheet: UIViewControllerRepresentable {
    let share: ListingShare

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: share.photos + [share.text], applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

/// Copies a piece of text, and says so for a moment.
struct CopyButton: View {
    let title: String
    let text: String

    @State private var copied = false

    var body: some View {
        Button {
            UIPasteboard.general.string = text
            copied = true
        } label: {
            Label(copied ? "Copié" : title, systemImage: copied ? "checkmark" : "doc.on.doc")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(SecondaryButtonStyle())
        .sensoryFeedback(.success, trigger: copied) { _, isCopied in isCopied }
        .task(id: copied) {
            guard copied else { return }
            try? await Task.sleep(for: .seconds(1.5))
            copied = false
        }
    }
}
