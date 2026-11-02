import SwiftUI

// MARK: - Surfaces
//
// Every surface in the app comes from here so the two pages stay consistent.
// The popover itself is already a material; inner surfaces are flat, low-contrast tints
// rather than more glass, which stacks into grey blobs.

extension View {
    /// A quiet inset surface: faint fill, hairline rim.
    func panelCard(cornerRadius: CGFloat = 12) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        return self
            .background(shape.fill(.primary.opacity(0.045)))
            .overlay(shape.strokeBorder(.primary.opacity(0.07), lineWidth: 1))
    }

    /// Liquid Glass on macOS 26, material before that. For floating HUDs over the desktop only.
    @ViewBuilder
    func glassSurface(cornerRadius: CGFloat = 20) -> some View {
        if #available(macOS 26, *) {
            glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
        } else {
            background(.regularMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(.white.opacity(0.12), lineWidth: 0.8))
        }
    }

    /// Groups views so adjacent shapes blend into each other on macOS 26. No-op before that.
    @ViewBuilder
    func glassGroup(spacing: CGFloat = 12) -> some View {
        if #available(macOS 26, *) {
            GlassEffectContainer(spacing: spacing) { self }
        } else {
            self
        }
    }
}

/// Flat button that matches `panelCard`. Pressed state darkens slightly.
struct QuietButtonStyle: ButtonStyle {
    var prominent = false

    func makeBody(configuration: Configuration) -> some View {
        let shape = RoundedRectangle(cornerRadius: 10, style: .continuous)
        configuration.label
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(prominent ? Color.white : .primary.opacity(0.9))
            .padding(.horizontal, 12)
            .frame(height: 30)
            .background(shape.fill(prominent ? Color.accentColor : .primary.opacity(configuration.isPressed ? 0.10 : 0.06)))
            .overlay(shape.strokeBorder(.primary.opacity(prominent ? 0 : 0.07), lineWidth: 1))
            .contentShape(shape)
            .opacity(configuration.isPressed && prominent ? 0.85 : 1)
    }
}

// MARK: - Tokens

/// Two semantic hues, both desaturated so they glow rather than shout: warm light, cool sound.
enum Theme {
    static let panelWidth: CGFloat = 320
    static let inset: CGFloat = 16
    static var contentWidth: CGFloat { panelWidth - inset * 2 }

    static let brightness = Color(red: 0.98, green: 0.80, blue: 0.45)
    static let volume = Color(red: 0.55, green: 0.76, blue: 1.00)
    static let muted = Color(red: 1.00, green: 0.50, blue: 0.52)

    static let title = Font.system(size: 13, weight: .semibold)
    static let body = Font.system(size: 12)
    static let caption = Font.system(size: 10.5)
    static let numeral = Font.system(size: 28, weight: .light, design: .rounded)
}

// MARK: - Controls

/// Small flat toggle chip. On reads as a solid pill, off as a faint one.
struct ToggleChip: View {
    let title: String
    let symbol: String
    @Binding var isOn: Bool

    var body: some View {
        Button {
            withAnimation(.spring(duration: 0.25, bounce: 0.15)) { isOn.toggle() }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: symbol)
                    .font(.system(size: 10, weight: .semibold))
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.9)
            }
            .foregroundStyle(isOn ? Color.black.opacity(0.85) : .primary.opacity(0.75))
            .padding(.horizontal, 8)
            .frame(maxWidth: .infinity)
            .frame(height: 26)
            .background(Capsule().fill(isOn ? Color.white.opacity(0.9) : .primary.opacity(0.06)))
            .overlay(Capsule().strokeBorder(.primary.opacity(isOn ? 0 : 0.07), lineWidth: 1))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}

/// A labelled slider row.
struct SliderRow: View {
    let title: String
    let symbol: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    var format: (Double) -> String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Image(systemName: symbol)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 16)
                Text(title)
                    .font(Theme.body)
                Spacer()
                Text(format(value))
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            Slider(value: $value, in: range)
                .controlSize(.small)
                .padding(.leading, 22)
        }
    }
}

/// Section title on the settings page.
struct SectionTitle: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 8)
    }
}

/// Stacks rows with hairline dividers inside one card.
struct InsetGroup<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        _VariadicView.Tree(DividedLayout()) { content }
            .panelCard()
    }

    private struct DividedLayout: _VariadicView_UnaryViewRoot {
        @ViewBuilder
        func body(children: _VariadicView.Children) -> some View {
            VStack(spacing: 0) {
                ForEach(children) { child in
                    child
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                    if child.id != children.last?.id {
                        Divider().opacity(0.4).padding(.leading, 40)
                    }
                }
            }
        }
    }
}
