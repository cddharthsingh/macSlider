import SwiftUI
import macSliderCore

/// Root of the menu bar popover. Two pages: the everyday panel and the set-once settings.
struct MenuPanelView: View {
    @Environment(Settings.self) private var settings
    let controller: SliderController

    @State private var showingSettings = false

    var body: some View {
        ZStack {
            if showingSettings {
                SettingsPage(onBack: { flip(false) })
                    .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                            removal: .move(edge: .trailing).combined(with: .opacity)))
            } else {
                mainPage
                    .transition(.asymmetric(insertion: .move(edge: .leading).combined(with: .opacity),
                                            removal: .move(edge: .leading).combined(with: .opacity)))
            }
        }
        .frame(width: Theme.panelWidth)
        .preferredColorScheme(colorScheme)
        .onAppear { controller.wantsLiveTouches = true }
        .onDisappear { controller.wantsLiveTouches = false }
        .onChange(of: settings.edgeWidth) { controller.applySettings() }
        .onChange(of: settings.sensitivity) { controller.applySettings() }
        .onChange(of: settings.isEnabled) { controller.applySettings() }
        .onChange(of: settings.mediaStripEnabled) { controller.applySettings() }
        .onChange(of: settings.bottomQuarterOnly) { controller.applySettings() }
        .onChange(of: settings.requiredModifier) { controller.applySettings() }
        .onChange(of: settings.topStripAction) { controller.applySettings() }
        .onChange(of: settings.magicMouseEnabled) { controller.applySettings() }
    }

    private var colorScheme: ColorScheme? {
        switch settings.appearance {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }

    private func flip(_ toSettings: Bool) {
        withAnimation(.spring(duration: 0.38, bounce: 0.1)) { showingSettings = toSettings }
    }

    // MARK: Main page

    private var mainPage: some View {
        @Bindable var settings = settings
        return VStack(spacing: 0) {
            header
                .padding(.bottom, 14)

            TrackpadPreview(controller: controller)
                .opacity(settings.isEnabled ? 1 : 0.5)
                .animation(.easeOut(duration: 0.2), value: settings.isEnabled)

            levels
                .padding(.top, 14)
                .padding(.horizontal, 2)

            if !controller.accessibilityGranted {
                permissionRow
                    .padding(.top, 14)
            }

            HStack(spacing: 6) {
                ToggleChip(title: "Haptics", symbol: "hand.tap", isOn: $settings.hapticsEnabled)
                ToggleChip(title: "Quick mute", symbol: "speaker.slash", isOn: $settings.quickMuteEnabled)
                ToggleChip(title: "Media strip", symbol: "playpause", isOn: $settings.mediaStripEnabled)
            }
            .padding(.top, 16)

            VStack(spacing: 8) {
                SliderRow(title: "Sensitivity", symbol: "gauge.with.dots.needle.33percent",
                          value: $settings.sensitivity, range: 0.5 ... 2.0) { String(format: "%.1f×", $0) }
                SliderRow(title: "Edge width", symbol: "arrow.left.and.right",
                          value: $settings.edgeWidth, range: 0.04 ... 0.2) { "\(Int($0 * 100))%" }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .panelCard()
            .padding(.top, 10)

            footer
                .padding(.top, 10)
        }
        .padding(Theme.inset)
    }

    private var header: some View {
        @Bindable var settings = settings
        return HStack(spacing: 8) {
            Text("macSlider")
                .font(Theme.title)
            Circle()
                .fill(settings.isEnabled ? Color.green : Color.secondary.opacity(0.4))
                .frame(width: 5, height: 5)
            Text(settings.isEnabled ? "Listening" : "Paused")
                .font(Theme.caption)
                .foregroundStyle(.secondary)
                .contentTransition(.opacity)
            Spacer()
            Toggle("", isOn: $settings.isEnabled)
                .toggleStyle(.switch)
                .controlSize(.small)
                .labelsHidden()
        }
        .padding(.horizontal, 2)
        .animation(.easeOut(duration: 0.2), value: settings.isEnabled)
    }

    /// Each value sits under the edge that controls it.
    private var levels: some View {
        let brightnessLeft = settings.brightnessEdge == .left
        let brightness = readout(value: controller.brightness, name: "Brightness",
                                 tint: Theme.brightness, leading: brightnessLeft)
        let volume = readout(value: controller.volume, name: controller.isMuted ? "Muted" : "Volume",
                             tint: controller.isMuted ? Theme.muted : Theme.volume, leading: !brightnessLeft)
        return HStack(alignment: .firstTextBaseline) {
            if brightnessLeft { brightness } else { volume }
            Spacer()
            if brightnessLeft { volume } else { brightness }
        }
    }

    private func readout(value: Float, name: String, tint: Color, leading: Bool) -> some View {
        VStack(alignment: leading ? .leading : .trailing, spacing: 1) {
            HStack(alignment: .firstTextBaseline, spacing: 1) {
                Text("\(Int((value * 100).rounded()))")
                    .font(Theme.numeral)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                Text("%")
                    .font(.system(size: 13, weight: .regular, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 5) {
                if leading { Circle().fill(tint).frame(width: 5, height: 5).shadow(color: tint.opacity(0.8), radius: 3) }
                Text(name)
                    .font(Theme.caption)
                    .foregroundStyle(.secondary)
                if !leading { Circle().fill(tint).frame(width: 5, height: 5).shadow(color: tint.opacity(0.8), radius: 3) }
            }
        }
        .animation(.spring(duration: 0.3), value: value)
    }

    private var permissionRow: some View {
        HStack(spacing: 10) {
            Image(systemName: "hand.raised")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 16)
            VStack(alignment: .leading, spacing: 1) {
                Text("Accessibility access needed")
                    .font(.system(size: 12, weight: .medium))
                Text("To press keys and hold the cursor still")
                    .font(Theme.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Open Settings", action: Permissions.openAccessibilitySettings)
                .buttonStyle(QuietButtonStyle(prominent: true))
                .controlSize(.small)
        }
        .padding(.leading, 12)
        .padding(.trailing, 6)
        .padding(.vertical, 6)
        .panelCard()
    }

    private var footer: some View {
        HStack(spacing: 6) {
            Button { flip(true) } label: {
                Label("Settings", systemImage: "slider.horizontal.3")
                    .frame(maxWidth: .infinity)
            }
            .keyboardShortcut(",", modifiers: .command)

            Button { OnboardingWindow.show() } label: {
                Image(systemName: "questionmark").frame(width: 14)
            }
            .help("Setup guide")

            Button { NSApp.terminate(nil) } label: {
                Image(systemName: "power").frame(width: 14)
            }
            .keyboardShortcut("q", modifiers: .command)
            .help("Quit macSlider")
        }
        .buttonStyle(QuietButtonStyle())
    }
}
