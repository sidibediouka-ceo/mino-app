import PhotosUI
import SwiftUI
import UIKit

/// "Immortaliser la tenue": take a photo or pick one from the library.
struct OutfitPhotoMenu<Label: View>: View {
    let onImage: (UIImage) -> Void
    @ViewBuilder let label: Label

    @State private var pickerItem: PhotosPickerItem?
    @State private var showingCamera = false

    var body: some View {
        Menu {
            if CameraPicker.isAvailable {
                Button("Prendre une photo", systemImage: "camera") { showingCamera = true }
            }
            PhotosPicker(selection: $pickerItem, matching: .images) {
                SwiftUI.Label("Choisir dans la photothèque", systemImage: "photo.on.rectangle")
            }
        } label: {
            label
        }
        .onChange(of: pickerItem) { _, item in
            guard let item else { return }
            pickerItem = nil
            Task {
                if let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data) {
                    onImage(image)
                }
            }
        }
        .fullScreenCover(isPresented: $showingCamera) {
            CameraPicker(onCapture: onImage)
                .ignoresSafeArea()
        }
    }
}

enum OutfitPhoto {
    /// Photos are kept at a reasonable size: sharp on screen, light on storage.
    static func storedData(for image: UIImage) -> Data? {
        let scale = min(1, 1600 / max(image.size.width, image.size.height))
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format)
            .image { _ in image.draw(in: CGRect(origin: .zero, size: size)) }
            .jpegData(compressionQuality: 0.8)
    }
}

/// The outfit photo, full screen: pinch to zoom, drag when zoomed, double tap to reset.
struct OutfitPhotoViewer: View {
    let image: UIImage

    @Environment(\.dismiss) private var dismiss
    @State private var scale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @GestureState private var pinch: CGFloat = 1
    @GestureState private var drag: CGSize = .zero

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .scaleEffect(scale * pinch)
                .offset(x: offset.width + drag.width, y: offset.height + drag.height)
                .gesture(
                    MagnifyGesture()
                        .updating($pinch) { value, state, _ in state = value.magnification }
                        .onEnded { value in
                            scale = min(max(scale * value.magnification, 1), 4)
                            if scale == 1 { offset = .zero }
                        }
                )
                .simultaneousGesture(
                    DragGesture()
                        .updating($drag) { value, state, _ in if scale > 1 { state = value.translation } }
                        .onEnded { value in
                            guard scale > 1 else { return }
                            offset.width += value.translation.width
                            offset.height += value.translation.height
                        }
                )
                .onTapGesture(count: 2) {
                    withAnimation(.snappy) {
                        scale = scale > 1 ? 1 : 2.5
                        offset = .zero
                    }
                }
                .accessibilityLabel("Photo de la tenue")
            Button { dismiss() } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.largeTitle)
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, .white.opacity(0.25))
            }
            .padding(20)
            .accessibilityLabel("Fermer")
        }
    }
}
