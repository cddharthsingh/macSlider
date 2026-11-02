import SwiftUI
import macSliderCore

/// A live trackpad: a thin luminous rail on each edge shows its level, fingers show where they land.
struct TrackpadPreview: View {
    @Environment(Settings.self) private var settings
    @Environment(\.colorScheme) private var scheme
    let controller: SliderController

    static let aspect: CGFloat = 1.5

    private let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let zone = max(8, settings.edgeWidth * w)

            ZStack {
                surface

                edgeRail(edge: settings.brightnessEdge, zone: zone, height: h, totalWidth: w,
                         level: CGFloat(controller.brightness), tint: Theme.brightness)
                edgeRail(edge: settings.volumeEdge, zone: zone, height: h, totalWidth: w,
                         level: CGFloat(controller.volume),
                         tint: controller.isMuted ? Theme.muted : Theme.volume)

                if settings.mediaStripEnabled {
                    strip(height: zone, active: controller.activeEdge == .bottom) {
                        HStack {
                            Image(systemName: "backward.fill")
                            Spacer()
                            if settings.doubleTapPlayPause { Image(systemName: "playpause.fill") }
                            Spacer()
                            Image(systemName: "forward.fill")
                        }
                        .padding(.horizontal, zone + 10)
                    }
                    .frame(width: w, height: h, alignment: .bottom)
                }

                if settings.topStripAction != .off {
                    strip(height: zone, active: controller.activeEdge == .top) {
                        Image(systemName: settings.topStripAction == .keyboardBacklight ? "keyboard" : "rectangle.on.rectangle")
                    }
                    .frame(width: w, height: h, alignment: .top)
                }

                cornerMarker("speaker.slash.fill", visible: settings.quickMuteEnabled)
                    .frame(width: w, height: h, alignment: .topTrailing)
                cornerMarker(settings.topLeftCorner.symbol, visible: settings.topLeftCorner != .nothing)
                    .frame(width: w, height: h, alignment: .topLeading)
                cornerMarker(settings.bottomLeftCorner.symbol, visible: settings.bottomLeftCorner != .nothing)
                    .frame(width: w, height: h, alignment: .bottomLeading)
                cornerMarker(settings.bottomRightCorner.symbol, visible: settings.bottomRightCorner != .nothing)
                    .frame(width: w, height: h, alignment: .bottomTrailing)

                Text(controller.lastGesture.isEmpty ? status : controller.lastGesture)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(controller.lastGesture.isEmpty ? .tertiary : .secondary)
                    .contentTransition(.opacity)
                    .animation(.easeOut(duration: 0.2), value: controller.lastGesture)

                ForEach(controller.liveTouches) { t in
                    fingerDot
                        .position(x: t.x * w, y: (1 - t.y) * h)
                        .transition(.scale(scale: 0.5).combined(with: .opacity))
                }
            }
            .clipShape(shape)
            .animation(.spring(duration: 0.35, bounce: 0.1), value: controller.volume)
            .animation(.spring(duration: 0.35, bounce: 0.1), value: controller.brightness)
            .animation(.easeOut(duration: 0.15), value: controller.activeEdge)
            .animation(.spring(duration: 0.18, bounce: 0.25), value: controller.liveTouches)
        }
        .frame(height: Theme.contentWidth / Self.aspect)
    }

    // MARK: Pieces

    private var dark: Bool { scheme == .dark }

    private var surface: some View {
        shape
            .fill(LinearGradient(colors: dark ? [Color(white: 0.16), Color(white: 0.10)]
                                              : [Color(white: 0.96), Color(white: 0.90)],
                                 startPoint: .top, endPoint: .bottom))
            .overlay(
                shape.strokeBorder(LinearGradient(colors: [.white.opacity(dark ? 0.18 : 0.9), .white.opacity(dark ? 0.04 : 0.3)],
                                                  startPoint: .top, endPoint: .bottom), lineWidth: 1)
            )
            .overlay(shape.strokeBorder(.black.opacity(dark ? 0.35 : 0.08), lineWidth: 1).padding(-1))
    }

    private var status: String {
        if !controller.accessibilityGranted { return "Waiting for Accessibility access" }
        if !controller.multitouchAvailable { return "No trackpad found" }
        if !settings.isEnabled { return "Paused" }
        return "Slide an edge"
    }

    private var fingerDot: some View {
        ZStack {
            Circle().strokeBorder(.primary.opacity(0.25), lineWidth: 1).frame(width: 26, height: 26)
            Circle().fill(.primary.opacity(0.85)).frame(width: 14, height: 14)
                .shadow(color: .primary.opacity(0.4), radius: 6)
        }
    }

    /// Faint zone band plus a thin lit rail on the outer edge whose length is the level.
    @ViewBuilder
    private func edgeRail(edge: macSliderCore.Edge, zone: CGFloat, height: CGFloat, totalWidth: CGFloat,
                          level: CGFloat, tint: Color) -> some View {
        let active = controller.activeEdge == edge
        let usable = settings.bottomQuarterOnly ? height * 0.25 : height
        let fill = max(6, usable * min(max(level, 0), 1))
        let railWidth: CGFloat = active ? 5 : 3
        let leading = edge == .left

        ZStack(alignment: leading ? .bottomLeading : .bottomTrailing) {
            Rectangle()
                .fill(.primary.opacity(active ? 0.07 : 0.03))
                .frame(width: zone, height: usable)
            Rectangle()
                .fill(.primary.opacity(0.08))
                .frame(width: railWidth, height: usable)
            Capsule()
                .fill(tint)
                .frame(width: railWidth, height: fill)
                .shadow(color: tint.opacity(active ? 0.9 : 0.55), radius: active ? 10 : 5)
                .padding(.vertical, 6)
        }
        .frame(width: zone, height: height, alignment: .bottom)
        .frame(width: totalWidth, height: height, alignment: leading ? .leading : .trailing)
    }

    private func strip<Content: View>(height: CGFloat, active: Bool, @ViewBuilder content: () -> Content) -> some View {
        content()
            .font(.system(size: 7, weight: .bold))
            .foregroundStyle(.tertiary)
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .background(Rectangle().fill(.primary.opacity(active ? 0.07 : 0.03)))
    }

    @ViewBuilder
    private func cornerMarker(_ symbol: String, visible: Bool) -> some View {
        if visible {
            Image(systemName: symbol)
                .font(.system(size: 7, weight: .bold))
                .foregroundStyle(.tertiary)
                .frame(width: 16, height: 16)
                .background(Circle().fill(.primary.opacity(0.06)))
                .padding(7)
        }
    }
}
