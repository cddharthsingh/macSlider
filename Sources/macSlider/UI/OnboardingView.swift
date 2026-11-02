import SwiftUI

struct OnboardingView: View {
    @Environment(Settings.self) private var settings
    let controller: SliderController
    var onDone: () -> Void = {}

    @State private var step = 0
    @State private var sawVolume = false
    @State private var sawBrightness = false

    var body: some View {
        VStack(spacing: 22) {
            Image(systemName: "rectangle.inset.filled")
                .font(.system(size: 44, weight: .light))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.tint)

            Group {
                switch step {
                case 0: welcome
                case 1: permission
                default: firstSlide
                }
            }
            .frame(maxWidth: .infinity)
            .transition(.opacity.combined(with: .move(edge: .trailing)))

            HStack {
                ForEach(0 ..< 3, id: \.self) { i in
                    Capsule()
                        .fill(i == step ? Color.accentColor : Color.secondary.opacity(0.3))
                        .frame(width: i == step ? 22 : 8, height: 8)
                }
            }

            HStack {
                if step > 0 {
                    Button("Back") { withAnimation { step -= 1 } }.buttonStyle(QuietButtonStyle())
                }
                Spacer()
                Button(step == 2 ? "Done" : "Continue") {
                    if step == 2 {
                        settings.hasCompletedOnboarding = true
                        onDone()
                    } else {
                        withAnimation(.spring(duration: 0.4)) { step += 1 }
                    }
                }
                .buttonStyle(QuietButtonStyle(prominent: true))
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(28)
        .frame(width: 440, height: 420)
        .onChange(of: controller.lastGesture) { _, new in
            if new == "Volume" { sawVolume = true }
            if new == "Brightness" { sawBrightness = true }
        }
    }

    private var welcome: some View {
        VStack(spacing: 10) {
            Text("Welcome to macSlider")
                .font(.system(size: 22, weight: .bold, design: .rounded))
            Text("Your trackpad edges become sliders. Volume on the right, brightness on the left, media along the bottom. Everything else is off until you turn it on.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var permission: some View {
        VStack(spacing: 14) {
            Text("One permission")
                .font(.system(size: 22, weight: .bold, design: .rounded))
            Text("macSlider needs Accessibility access to press the volume and brightness keys for you and to keep the pointer still while you slide. Nothing is recorded or sent anywhere.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 10) {
                Image(systemName: controller.accessibilityGranted ? "checkmark.circle.fill" : "circle.dashed")
                    .foregroundStyle(controller.accessibilityGranted ? .green : .secondary)
                Text(controller.accessibilityGranted ? "Accessibility granted" : "Waiting for permission")
                    .font(.system(size: 12, weight: .medium))
                Spacer()
                if !controller.accessibilityGranted {
                    Button("Open System Settings", action: Permissions.openAccessibilitySettings)
                        .controlSize(.small)
                }
            }
            .padding(12)
            .panelCard()
        }
    }

    private var firstSlide: some View {
        VStack(spacing: 14) {
            Text("Try your first slide")
                .font(.system(size: 22, weight: .bold, design: .rounded))
            TrackpadPreview(controller: controller)
                .frame(height: 150)
            HStack(spacing: 10) {
                check("Slide the right edge for volume", done: sawVolume)
                check("Slide the left edge for brightness", done: sawBrightness)
            }
        }
        .onAppear { controller.wantsLiveTouches = true }
        .onDisappear { controller.wantsLiveTouches = false }
    }

    private func check(_ text: String, done: Bool) -> some View {
        HStack(spacing: 8) {
            Image(systemName: done ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(done ? .green : .secondary)
            Text(text).font(.system(size: 11))
            Spacer(minLength: 0)
        }
        .padding(10)
        .frame(maxWidth: .infinity)
        .panelCard()
        .animation(.spring(duration: 0.3), value: done)
    }
}
