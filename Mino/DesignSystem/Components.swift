import MinoKit
import SwiftUI

extension View {
    /// The standard rounded surface used for every card.
    func minoCard(padding: CGFloat = 16) -> some View {
        self
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .shadow(color: .black.opacity(0.05), radius: 12, y: 4)
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .foregroundStyle(Theme.onForest)
            .background(Theme.forest, in: Capsule())
            .opacity(configuration.isPressed ? 0.8 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.snappy(duration: 0.15), value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .padding(.vertical, 10)
            .padding(.horizontal, 14)
            .foregroundStyle(Theme.forest)
            .background(Theme.sage.opacity(0.22), in: Capsule())
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

/// A selectable capsule, the basic input of Mino: tapping beats typing.
struct Chip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(isSelected ? .semibold : .regular))
                .padding(.vertical, 8)
                .padding(.horizontal, 14)
                .foregroundStyle(isSelected ? Theme.onForest : Theme.forest)
                .background(isSelected ? Theme.forest : Theme.sage.opacity(0.18), in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// A horizontal row of chips for picking one value.
struct ChipPicker<Value: Hashable>: View {
    let options: [Value]
    @Binding var selection: Value
    let title: (Value) -> String

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(options, id: \.self) { option in
                        Chip(title: title(option), isSelected: option == selection) {
                            selection = option
                        }
                        .id(option)
                    }
                }
                .padding(.horizontal, 2)
            }
            .onAppear { proxy.scrollTo(selection, anchor: .center) }
        }
    }
}

/// A garment's photo on a soft background, or a quiet placeholder.
struct GarmentImage: View {
    let photo: Data?

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Theme.sage.opacity(0.14))
            if let photo, let image = UIImage(data: photo) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .padding(8)
            } else {
                Image(systemName: "tshirt")
                    .font(.title2)
                    .foregroundStyle(Theme.sage)
            }
        }
        .accessibilityHidden(true)
    }
}

struct ColorSwatch: View {
    let color: GarmentColor
    var size: CGFloat = 28

    var body: some View {
        Group {
            if let swatch = color.swatch {
                Circle().fill(Color(red: swatch.red, green: swatch.green, blue: swatch.blue))
            } else {
                Circle().fill(AngularGradient(colors: [.red, .yellow, .green, .blue, .purple, .red], center: .center))
            }
        }
        .frame(width: size, height: size)
        .overlay(Circle().strokeBorder(Theme.secondaryText.opacity(0.3), lineWidth: 1))
    }
}

/// A child's initial in a soft circle.
struct ChildAvatar: View {
    let name: String
    var size: CGFloat = 36

    var body: some View {
        Text(name.prefix(1).uppercased())
            .font(.system(size: size * 0.45, weight: .semibold, design: .rounded))
            .foregroundStyle(Theme.onForest)
            .frame(width: size, height: size)
            .background(Theme.sage, in: Circle())
            .accessibilityHidden(true)
    }
}

/// A large empty state with one clear next step.
struct EmptyStateView: View {
    let symbol: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 44))
                .foregroundStyle(Theme.sage)
            Text(title)
                .font(.title3.weight(.semibold))
                .foregroundStyle(Theme.forest)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(Theme.secondaryText)
                .multilineTextAlignment(.center)
        }
        .padding(32)
        .frame(maxWidth: .infinity)
    }
}
