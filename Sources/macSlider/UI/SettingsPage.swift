import SwiftUI

struct SettingsPage: View {
    @Environment(Settings.self) private var settings
    let onBack: () -> Void
    @State private var launchAtLogin = Settings.shared.launchAtLogin

    private static let height: CGFloat = 520

    var body: some View {
        @Bindable var settings = settings
        VStack(spacing: 0) {
            ZStack {
                Text("Settings")
                    .font(Theme.title)
                HStack {
                    Button(action: onBack) {
                        Label("Back", systemImage: "chevron.left")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .buttonStyle(QuietButtonStyle())
                    .keyboardShortcut(.escape, modifiers: [])
                    Spacer()
                }
            }
            .padding(.horizontal, Theme.inset)
            .padding(.top, Theme.inset)
            .padding(.bottom, 10)

            ScrollView {
                VStack(spacing: 16) {
                    section("Edges") {
                        toggleRow("Swap sides", "arrow.left.arrow.right", "Brightness on the right", $settings.swapSides)
                        toggleRow("Bottom quarter only", "rectangle.bottomhalf.inset.filled", "Only the lower part of each edge responds", $settings.bottomQuarterOnly)
                        toggleRow("Flip vertical axis", "arrow.up.arrow.down", "If sliding up lowers the level", $settings.flipVerticalAxis)
                        toggleRow("Magic Mouse", "magicmouse", "Slide on the mouse's top edges too", $settings.magicMouseEnabled)
                        pickerRow("Require modifier", "command") {
                            Picker("", selection: $settings.requiredModifier) {
                                ForEach(RequiredModifier.allCases) { Text($0.label).tag($0) }
                            }
                        }
                    }

                    section("While sliding") {
                        toggleRow("Freeze cursor", "cursorarrow.slash", "Pointer stays hidden and still", $settings.freezeCursor)
                        toggleRow("Precise sliding", "dial.low", "Quarter steps without holding any keys", $settings.preciseSliding)
                        toggleRow("Fine control with ⇧⌥", "keyboard", "Hold Shift-Option for quarter steps", $settings.fineControlWithModifiers)
                        pickerRow("Haptic strength", "hand.tap") {
                            Picker("", selection: $settings.hapticStrength) {
                                ForEach(HapticStrength.allCases) { Text($0.label).tag($0) }
                            }
                            .pickerStyle(.segmented)
                            .frame(width: 160)
                        }
                        pickerRow("Level control", "waveform.path") {
                            Picker("", selection: $settings.levelMode) {
                                ForEach(LevelMode.allCases) { Text($0.label).tag($0) }
                            }
                        }
                    }

                    section("Media strip") {
                        toggleRow("Reverse swipe", "arrow.uturn.left", "Swipe left for next track", $settings.reverseSwipe)
                        toggleRow("Double-tap to play or pause", "playpause", "Bottom-right corner", $settings.doubleTapPlayPause)
                    }

                    section("Corners and top strip", footnote: "Top-right is reserved for Quick mute. Double-tap a corner to trigger it.") {
                        pickerRow("Top strip", "rectangle.tophalf.inset.filled") {
                            Picker("", selection: $settings.topStripAction) {
                                ForEach(TopStripAction.allCases) { Text($0.label).tag($0) }
                            }
                        }
                        cornerRow("Top-left", "arrow.up.left", $settings.topLeftCorner)
                        cornerRow("Bottom-left", "arrow.down.left", $settings.bottomLeftCorner)
                        cornerRow("Bottom-right", "arrow.down.right", $settings.bottomRightCorner)
                        if usesShortcut {
                            HStack {
                                rowLabel("Shortcut name", "bolt")
                                Spacer()
                                TextField("My Shortcut", text: $settings.shortcutName)
                                    .textFieldStyle(.roundedBorder)
                                    .controlSize(.small)
                                    .frame(width: 150)
                            }
                        }
                    }

                    section("App") {
                        pickerRow("Appearance", "circle.lefthalf.filled") {
                            Picker("", selection: $settings.appearance) {
                                ForEach(AppAppearance.allCases) { Text($0.label).tag($0) }
                            }
                            .pickerStyle(.segmented)
                            .frame(width: 160)
                        }
                        HStack {
                            rowLabel("Open at login", "power")
                            Spacer()
                            Toggle("", isOn: $launchAtLogin)
                                .toggleStyle(.switch)
                                .controlSize(.small)
                                .labelsHidden()
                        }
                        .onChange(of: launchAtLogin) { settings.launchAtLogin = launchAtLogin }
                        HStack {
                            rowLabel("Accessibility", "hand.raised")
                            Spacer()
                            if Permissions.accessibilityGranted {
                                Label("Granted", systemImage: "checkmark.circle.fill")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(.green)
                            } else {
                                Button("Open System Settings", action: Permissions.openAccessibilitySettings)
                                    .buttonStyle(QuietButtonStyle())
                            }
                        }
                    }

                    Text("macSlider \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "dev") · MIT licensed")
                        .font(Theme.caption)
                        .foregroundStyle(.tertiary)
                        .padding(.bottom, 4)
                }
                .padding(.horizontal, Theme.inset)
                .padding(.bottom, Theme.inset)
            }
            .scrollIndicators(.hidden)
        }
        .frame(width: Theme.panelWidth, height: Self.height)
    }

    private var usesShortcut: Bool {
        [settings.topLeftCorner, settings.bottomLeftCorner, settings.bottomRightCorner].contains(.runShortcut)
    }

    // MARK: Rows

    @ViewBuilder
    private func section<Content: View>(_ title: String, footnote: String? = nil,
                                        @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionTitle(text: title)
            InsetGroup { content() }
            if let footnote {
                Text(footnote)
                    .font(Theme.caption)
                    .foregroundStyle(.secondary)
                    .padding(.leading, 6)
            }
        }
    }

    private func rowLabel(_ title: String, _ symbol: String, subtitle: String? = nil) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 18, height: 16)
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(Theme.body)
                if let subtitle {
                    Text(subtitle)
                        .font(Theme.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private func toggleRow(_ title: String, _ symbol: String, _ subtitle: String, _ binding: Binding<Bool>) -> some View {
        HStack(spacing: 8) {
            rowLabel(title, symbol, subtitle: subtitle)
            Spacer(minLength: 8)
            Toggle("", isOn: binding)
                .toggleStyle(.switch)
                .controlSize(.small)
                .labelsHidden()
        }
    }

    private func pickerRow<P: View>(_ title: String, _ symbol: String, @ViewBuilder picker: () -> P) -> some View {
        HStack {
            rowLabel(title, symbol)
            Spacer()
            picker()
                .labelsHidden()
                .controlSize(.small)
                .fixedSize()
        }
    }

    private func cornerRow(_ title: String, _ symbol: String, _ binding: Binding<CornerAction>) -> some View {
        pickerRow(title, symbol) {
            Picker("", selection: binding) {
                ForEach(CornerAction.allCases) { Label($0.label, systemImage: $0.symbol).tag($0) }
            }
        }
    }
}
