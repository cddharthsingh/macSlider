import AppKit
import macSliderCore
import Foundation
import Observation

/// Central coordinator. One instance for the app's lifetime.
///
/// Data flow: MultitouchService -> GestureEngine -> `handle(_:)` -> MediaKey / KeyPress / Shortcuts.
/// UI reads the observable properties below; nothing in the UI touches system APIs directly.
@Observable
@MainActor
final class SliderController {
    static let shared = SliderController()

    // Live state for the UI
    private(set) var volume: Float = 0
    private(set) var isMuted = false
    private(set) var brightness: Float = 0
    private(set) var activeEdge: Edge?
    private(set) var lastGesture: String = ""
    private(set) var liveTouches: [Touch] = []
    private(set) var accessibilityGranted = Permissions.accessibilityGranted
    private(set) var multitouchAvailable = MultitouchService.shared.isAvailable

    /// Set by the menu panel while it is visible so finger dots render live.
    var wantsLiveTouches = false

    private let settings = Settings.shared
    private let engine = GestureEngine()
    private let freezer = CursorFreezer()
    private let volumeMonitor = VolumeMonitor()
    private let brightnessMonitor = BrightnessMonitor()
    private var haptics: HapticEngine?
    private var permissionTimer: Timer?
    /// Absolute level being dragged in Direct mode; nil between slides.
    private var slideLevel: Float?

    private init() {
        volumeMonitor.onChange = { level, muted in
            MainActor.assumeIsolated {
                let c = SliderController.shared
                c.volume = level
                c.isMuted = muted
            }
        }
        brightness = brightnessMonitor.level ?? 0

        engine.onEvent = { event in
            MainActor.assumeIsolated { SliderController.shared.handle(event) }
        }
        // Frames arrive on the multitouch thread. Everything downstream runs on main so the
        // engine's state machine never races with its grace timers.
        MultitouchService.shared.onFrame = { frame in
            DispatchQueue.main.async {
                MainActor.assumeIsolated { SliderController.shared.ingest(frame) }
            }
        }
    }

    private func ingest(_ frame: TouchFrame) {
        engine.process(frame)
        if wantsLiveTouches { liveTouches = frame.touches.filter(\.isDown) }
    }

    func start() {
        applySettings()
        if accessibilityGranted {
            freezer.install()
        } else {
            Permissions.requestAccessibility()
            permissionTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { _ in
                MainActor.assumeIsolated {
                    let c = SliderController.shared
                    guard Permissions.accessibilityGranted else { return }
                    c.accessibilityGranted = true
                    c.freezer.install()
                    c.permissionTimer?.invalidate()
                }
            }
        }
        MultitouchService.shared.includeMagicMouse = settings.magicMouseEnabled
        MultitouchService.shared.startListening()
        haptics = HapticEngine(deviceID: MultitouchService.shared.builtInDeviceID)
    }

    /// Call after any setting that changes zone geometry.
    func applySettings() {
        let s = settings
        var c = ZoneConfig()
        c.edgeWidth = s.edgeWidth
        c.bottomPortionOnly = s.bottomQuarterOnly
        // Sensitivity 0.5...2 maps to step distance 0.09...0.0225 (larger = slower).
        c.stepDistance = 0.045 / s.sensitivity
        c.topStepDistance = s.topStripAction == .switchSpaces ? 0.25 : c.stepDistance
        c.verticalEdgesEnabled = s.isEnabled
        c.bottomStripEnabled = s.isEnabled && s.mediaStripEnabled
        c.topStripEnabled = s.isEnabled && s.topStripAction != .off
        c.cornersEnabled = s.isEnabled
        c.requireModifier = { Modifiers.isHeld(s.requiredModifier) }
        engine.config = c
        MultitouchService.shared.includeMagicMouse = s.magicMouseEnabled
    }

    // MARK: Gesture handling

    private func handle(_ event: GestureEvent) {
        let s = settings
        switch event {
        case .slideBegan(let edge):
            activeEdge = edge
            if s.freezeCursor { freezer.freeze() }

        case .slideEnded:
            activeEdge = nil
            slideLevel = nil
            freezer.thaw()

        case .slideStep(let edge, let steps):
            slide(edge: edge, steps: steps)

        case .swipe(let edge, let direction):
            guard edge == .bottom, s.mediaStripEnabled else { return }
            let dir = s.reverseSwipe ? -direction : direction
            (dir > 0 ? MediaKey.next : MediaKey.previous).press()
            lastGesture = dir > 0 ? "Next track" : "Previous track"
            tick()

        case .tap:
            break

        case .doubleTap(let corner):
            run(action(for: corner))
        }
    }

    private func slide(edge: Edge, steps rawSteps: Int) {
        let s = settings
        let steps = s.flipVerticalAxis && (edge == .left || edge == .right) ? -rawSteps : rawSteps
        let fine = s.preciseSliding || (s.fineControlWithModifiers && Modifiers.fineControlHeld)

        if edge == s.volumeEdge {
            lastGesture = "Volume"
            if s.levelMode == .direct, VolumeWriter.isSupported {
                slideLevel = (slideLevel ?? volume) + Float(steps) * (fine ? 1 / 64 : 1 / 16)
                slideLevel = min(max(slideLevel!, 0), 1)
                VolumeWriter.set(slideLevel!)
                GlassHUD.shared.show(.volume, level: slideLevel!)
                tick()
            } else {
                repeatPress(steps > 0 ? .soundUp : .soundDown, count: abs(steps), fine: fine)
            }
        } else if edge == s.brightnessEdge {
            lastGesture = "Brightness"
            if s.levelMode == .direct, BrightnessWriter.isSupported {
                slideLevel = (slideLevel ?? (brightnessMonitor.level ?? brightness)) + Float(steps) * (fine ? 1 / 64 : 1 / 16)
                slideLevel = min(max(slideLevel!, 0), 1)
                BrightnessWriter.set(slideLevel!)
                brightness = slideLevel!
                GlassHUD.shared.show(.brightness, level: slideLevel!)
                tick()
            } else {
                repeatPress(steps > 0 ? .brightnessUp : .brightnessDown, count: abs(steps), fine: fine)
                brightness = brightnessMonitor.level ?? brightness
            }
        } else if edge == .top {
            switch s.topStripAction {
            case .keyboardBacklight:
                repeatPress(steps > 0 ? .illuminationUp : .illuminationDown, count: abs(steps))
                lastGesture = "Keyboard backlight"
            case .switchSpaces:
                KeyPress.switchSpace(direction: steps)
                tick()
                lastGesture = "Spaces"
            case .off:
                break
            }
        }
    }

    private func repeatPress(_ key: MediaKey, count: Int, fine: Bool = false) {
        guard count > 0 else { return }
        for _ in 0 ..< min(count, 4) { key.press(fine: fine) }
        tick()
    }

    private func action(for corner: Corner) -> CornerAction {
        let s = settings
        switch corner {
        case .topRight: return s.quickMuteEnabled ? .muteToggle : .nothing
        case .topLeft: return s.topLeftCorner
        case .bottomLeft: return s.bottomLeftCorner
        case .bottomRight:
            if s.mediaStripEnabled, s.doubleTapPlayPause { return .playPause }
            return s.bottomRightCorner
        }
    }

    private func run(_ action: CornerAction) {
        switch action {
        case .nothing: return
        case .muteToggle:
            if settings.levelMode == .direct, VolumeWriter.isSupported {
                VolumeWriter.setMuted(!isMuted)
                GlassHUD.shared.show(isMuted ? .volume : .muted, level: isMuted ? volume : 0)
            } else {
                MediaKey.mute.press()
            }
            haptics?.buzz()
            lastGesture = "Mute"
            return
        case .playPause: MediaKey.play.press(); lastGesture = "Play / pause"
        case .missionControl: KeyPress.missionControl(); lastGesture = "Mission Control"
        case .showDesktop: KeyPress.showDesktop(); lastGesture = "Show desktop"
        case .lockScreen: KeyPress.lockScreen(); lastGesture = "Lock screen"
        case .runShortcut: ShortcutsRunner.run(settings.shortcutName); lastGesture = "Shortcut"
        }
        tick()
    }

    private func tick() {
        guard settings.hapticsEnabled else { return }
        haptics?.tick(settings.hapticStrength)
    }
}
