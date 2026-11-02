import Foundation
import macSliderCore
import Observation
import ServiceManagement

enum RequiredModifier: String, CaseIterable, Identifiable {
    case noModifier, fn, option
    var id: String { rawValue }
    var label: String {
        switch self {
        case .noModifier: "None"
        case .fn: "Fn (Globe)"
        case .option: "Option"
        }
    }
}

enum HapticStrength: String, CaseIterable, Identifiable {
    case light, medium, strong
    var id: String { rawValue }
    var label: String { rawValue.capitalized }
}

enum AppAppearance: String, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }
    var label: String { rawValue.capitalized }
}

/// What a corner tap or double tap does. Add a case here and handle it in `ActionRunner`.
enum CornerAction: String, CaseIterable, Identifiable {
    case nothing
    case muteToggle
    case playPause
    case missionControl
    case showDesktop
    case lockScreen
    case runShortcut

    var id: String { rawValue }
    var label: String {
        switch self {
        case .nothing: "Nothing"
        case .muteToggle: "Toggle mute"
        case .playPause: "Play / pause"
        case .missionControl: "Mission Control"
        case .showDesktop: "Show desktop"
        case .lockScreen: "Lock screen"
        case .runShortcut: "Run a Shortcut"
        }
    }
    var symbol: String {
        switch self {
        case .nothing: "circle.dashed"
        case .muteToggle: "speaker.slash.fill"
        case .playPause: "playpause.fill"
        case .missionControl: "rectangle.3.group"
        case .showDesktop: "menubar.dock.rectangle"
        case .lockScreen: "lock.fill"
        case .runShortcut: "bolt.fill"
        }
    }
}

/// What sliding along the top strip does.
enum TopStripAction: String, CaseIterable, Identifiable {
    case off
    case keyboardBacklight
    case switchSpaces

    var id: String { rawValue }
    var label: String {
        switch self {
        case .off: "Off"
        case .keyboardBacklight: "Keyboard backlight"
        case .switchSpaces: "Switch Spaces"
        }
    }
}

/// How a slide changes the system level.
enum LevelMode: String, CaseIterable, Identifiable {
    /// Synthesises the volume / brightness keys. macOS draws its own HUD. 16 steps, or 64 with fine control.
    case systemKeys
    /// Writes the level through CoreAudio / DisplayServices and shows macSlider's glass HUD. Continuous.
    case direct

    var id: String { rawValue }
    var label: String {
        switch self {
        case .systemKeys: "System keys (native HUD)"
        case .direct: "Direct (smooth, glass HUD)"
        }
    }
}

@Observable
final class Settings {
    static let shared = Settings()
    private let d = UserDefaults.standard

    // MARK: Everyday controls

    var isEnabled: Bool { didSet { d.set(isEnabled, forKey: "isEnabled") } }
    var hapticsEnabled: Bool { didSet { d.set(hapticsEnabled, forKey: "hapticsEnabled") } }
    var hapticStrength: HapticStrength { didSet { d.set(hapticStrength.rawValue, forKey: "hapticStrength") } }
    var quickMuteEnabled: Bool { didSet { d.set(quickMuteEnabled, forKey: "quickMuteEnabled") } }
    var mediaStripEnabled: Bool { didSet { d.set(mediaStripEnabled, forKey: "mediaStripEnabled") } }
    var doubleTapPlayPause: Bool { didSet { d.set(doubleTapPlayPause, forKey: "doubleTapPlayPause") } }
    var reverseSwipe: Bool { didSet { d.set(reverseSwipe, forKey: "reverseSwipe") } }

    /// 0.5 (slow) ... 2.0 (fast). Converted into step distance.
    var sensitivity: Double { didSet { d.set(sensitivity, forKey: "sensitivity") } }
    /// Fraction of the trackpad that counts as an edge, 0.04 ... 0.14.
    var edgeWidth: Double { didSet { d.set(edgeWidth, forKey: "edgeWidth") } }

    // MARK: While sliding

    var preciseSliding: Bool { didSet { d.set(preciseSliding, forKey: "preciseSliding") } }
    var fineControlWithModifiers: Bool { didSet { d.set(fineControlWithModifiers, forKey: "fineControlWithModifiers") } }
    var freezeCursor: Bool { didSet { d.set(freezeCursor, forKey: "freezeCursor") } }
    var requiredModifier: RequiredModifier { didSet { d.set(requiredModifier.rawValue, forKey: "requiredModifier") } }
    var levelMode: LevelMode { didSet { d.set(levelMode.rawValue, forKey: "levelMode") } }
    var flipVerticalAxis: Bool { didSet { d.set(flipVerticalAxis, forKey: "flipVerticalAxis") } }

    // MARK: Layout

    var swapSides: Bool { didSet { d.set(swapSides, forKey: "swapSides") } }
    var bottomQuarterOnly: Bool { didSet { d.set(bottomQuarterOnly, forKey: "bottomQuarterOnly") } }
    var magicMouseEnabled: Bool { didSet { d.set(magicMouseEnabled, forKey: "magicMouseEnabled") } }

    // MARK: Extras beyond the original

    var topStripAction: TopStripAction { didSet { d.set(topStripAction.rawValue, forKey: "topStripAction") } }
    var topLeftCorner: CornerAction { didSet { d.set(topLeftCorner.rawValue, forKey: "topLeftCorner") } }
    var bottomLeftCorner: CornerAction { didSet { d.set(bottomLeftCorner.rawValue, forKey: "bottomLeftCorner") } }
    var bottomRightCorner: CornerAction { didSet { d.set(bottomRightCorner.rawValue, forKey: "bottomRightCorner") } }
    var shortcutName: String { didSet { d.set(shortcutName, forKey: "shortcutName") } }

    // MARK: App

    var appearance: AppAppearance { didSet { d.set(appearance.rawValue, forKey: "appearance") } }
    var hasCompletedOnboarding: Bool { didSet { d.set(hasCompletedOnboarding, forKey: "hasCompletedOnboarding") } }

    var launchAtLogin: Bool {
        get { SMAppService.mainApp.status == .enabled }
        set {
            do {
                if newValue { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            } catch {
                NSLog("Launch at login failed: \(error)")
            }
        }
    }

    // MARK: Derived

    var brightnessEdge: Edge { swapSides ? .right : .left }
    var volumeEdge: Edge { swapSides ? .left : .right }

    private init() {
        let d = self.d
        func bool(_ k: String, _ def: Bool) -> Bool { d.object(forKey: k) as? Bool ?? def }
        func dbl(_ k: String, _ def: Double) -> Double { d.object(forKey: k) as? Double ?? def }
        func str(_ k: String, _ def: String) -> String { d.string(forKey: k) ?? def }

        isEnabled = bool("isEnabled", true)
        hapticsEnabled = bool("hapticsEnabled", true)
        hapticStrength = HapticStrength(rawValue: str("hapticStrength", "light")) ?? .light
        quickMuteEnabled = bool("quickMuteEnabled", true)
        mediaStripEnabled = bool("mediaStripEnabled", true)
        doubleTapPlayPause = bool("doubleTapPlayPause", false)
        reverseSwipe = bool("reverseSwipe", false)
        sensitivity = dbl("sensitivity", 1.0)
        edgeWidth = dbl("edgeWidth", 0.07)
        preciseSliding = bool("preciseSliding", false)
        fineControlWithModifiers = bool("fineControlWithModifiers", true)
        freezeCursor = bool("freezeCursor", true)
        requiredModifier = RequiredModifier(rawValue: str("requiredModifier", "noModifier")) ?? .noModifier
        levelMode = LevelMode(rawValue: str("levelMode", "systemKeys")) ?? .systemKeys
        flipVerticalAxis = bool("flipVerticalAxis", false)
        swapSides = bool("swapSides", false)
        bottomQuarterOnly = bool("bottomQuarterOnly", false)
        magicMouseEnabled = bool("magicMouseEnabled", false)
        topStripAction = TopStripAction(rawValue: str("topStripAction", "off")) ?? .off
        topLeftCorner = CornerAction(rawValue: str("topLeftCorner", "nothing")) ?? .nothing
        bottomLeftCorner = CornerAction(rawValue: str("bottomLeftCorner", "nothing")) ?? .nothing
        bottomRightCorner = CornerAction(rawValue: str("bottomRightCorner", "nothing")) ?? .nothing
        shortcutName = str("shortcutName", "")
        appearance = AppAppearance(rawValue: str("appearance", "system")) ?? .system
        hasCompletedOnboarding = bool("hasCompletedOnboarding", false)
    }
}
