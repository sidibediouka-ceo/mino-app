import MinoKit
import SwiftUI

extension View {
    /// The standard rounded surface.
    func minoCard(padding: CGFloat = 16) -> some View {
        self
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .shadow(color: .black.opacity(0.06), radius: 16, y: 6)
    }
}

/// The one action that matters on a screen: full width, colourful.
struct PrimaryButtonStyle: ButtonStyle {
    var color: Color = Theme.accent

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.headline, design: .rounded))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .foregroundStyle(Theme.onAccent)
            .background(color, in: Capsule())
            .opacity(configuration.isPressed ? 0.85 : 1)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.snappy(duration: 0.15), value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.subheadline, design: .rounded).weight(.semibold))
            .padding(.vertical, 10)
            .padding(.horizontal, 16)
            .foregroundStyle(Theme.ink)
            .background(Theme.chip, in: Capsule())
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
                .font(.system(.subheadline, design: .rounded).weight(isSelected ? .semibold : .regular))
                .padding(.vertical, 8)
                .padding(.horizontal, 14)
                .foregroundStyle(isSelected ? Theme.background : Theme.ink)
                .background(isSelected ? Theme.ink : Theme.chip, in: Capsule())
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

/// A garment laid flat on a white tile, like a flat-lay photo.
struct GarmentImage: View {
    let photo: Data?

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Theme.card)
                .shadow(color: .black.opacity(0.07), radius: 8, y: 3)
            if let photo, let image = UIImage(data: photo) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .padding(10)
            } else {
                Image(systemName: "tshirt")
                    .font(.title2)
                    .foregroundStyle(Theme.secondaryText)
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

/// A child's initial in their own colour.
struct ChildAvatar: View {
    let name: String
    let color: Color
    var size: CGFloat = 36

    var body: some View {
        Text(name.prefix(1).uppercased())
            .font(.system(size: size * 0.45, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(color, in: Circle())
            .accessibilityHidden(true)
    }
}

/// A large empty state with one clear next step.
struct EmptyStateView<Action: View>: View {
    let symbol: String
    let title: String
    let message: String
    @ViewBuilder var action: Action

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 44))
                .foregroundStyle(Theme.accent)
            Text(title)
                .font(.system(.title3, design: .rounded).weight(.bold))
                .foregroundStyle(Theme.ink)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(Theme.secondaryText)
                .multilineTextAlignment(.center)
            action
                .padding(.top, 4)
        }
        .padding(32)
        .frame(maxWidth: .infinity)
    }
}

extension EmptyStateView where Action == EmptyView {
    init(symbol: String, title: String, message: String) {
        self.init(symbol: symbol, title: title, message: message) { EmptyView() }
    }
}
