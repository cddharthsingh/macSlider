import AppKit
import ApplicationServices
import Foundation

// MARK: - Haptics

/// Plays a tick under the finger. Uses the private MTActuator API when available so strength
/// can vary, and falls back to NSHapticFeedbackManager otherwise.
final class HapticEngine {
    private typealias CreateFn = @convention(c) (UInt64) -> Unmanaged<CFTypeRef>?
    private typealias OpenFn = @convention(c) (CFTypeRef) -> Int32
    private typealias ActuateFn = @convention(c) (CFTypeRef, Int32, UInt32, Float, Float) -> Int32

    private var actuator: CFTypeRef?
    private var actuate: ActuateFn?

    init(deviceID: UInt64?) {
        guard let deviceID,
              let h = dlopen("/System/Library/PrivateFrameworks/MultitouchSupport.framework/MultitouchSupport", RTLD_NOW),
              let c = dlsym(h, "MTActuatorCreateFromDeviceID"),
              let o = dlsym(h, "MTActuatorOpen"),
              let a = dlsym(h, "MTActuatorActuate") else { return }

        let create = unsafeBitCast(c, to: CreateFn.self)
        let open = unsafeBitCast(o, to: OpenFn.self)
        guard let ref = create(deviceID)?.takeRetainedValue(), open(ref) == 0 else { return }
        actuator = ref
        actuate = unsafeBitCast(a, to: ActuateFn.self)
    }

    func tick(_ strength: HapticStrength) {
        if let actuator, let actuate {
            // Actuation IDs observed in the wild: 3 weak, 4 medium, 6 strong.
            let id: Int32 = switch strength {
            case .light: 3
            case .medium: 4
            case .strong: 6
            }
            _ = actuate(actuator, id, 0, 0, 0)
        } else {
            let pattern: NSHapticFeedbackManager.FeedbackPattern = strength == .strong ? .levelChange : .alignment
            NSHapticFeedbackManager.defaultPerformer.perform(pattern, performanceTime: .now)
        }
    }

    /// Longer buzz used for mute so you can feel it without looking.
    func buzz() {
        tick(.strong)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { [weak self] in self?.tick(.strong) }
    }
}

// MARK: - Cursor freeze and click suppression

/// Installs a CGEventTap that, while a slide is active, swallows pointer motion and clicks
/// so the cursor stays put and a tap-to-click on the edge does not land in the app below.
final class CursorFreezer {
    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private(set) var isFrozen = false
    private var suppressClicksUntil: TimeInterval = 0

    var isInstalled: Bool { tap != nil }

    func install() {
        guard tap == nil else { return }
        let mask: CGEventMask =
            (1 << CGEventType.mouseMoved.rawValue) |
            (1 << CGEventType.leftMouseDown.rawValue) |
            (1 << CGEventType.leftMouseUp.rawValue) |
            (1 << CGEventType.leftMouseDragged.rawValue) |
            (1 << CGEventType.rightMouseDown.rawValue) |
            (1 << CGEventType.rightMouseUp.rawValue)

        let info = Unmanaged.passUnretained(self).toOpaque()
        tap = CGEvent.tapCreate(tap: .cgSessionEventTap,
                                place: .headInsertEventTap,
                                options: .defaultTap,
                                eventsOfInterest: mask,
                                callback: cursorTapCallback,
                                userInfo: info)
        guard let tap else { return }
        runLoopSource = CFMachPortCreateRunLoopSource(nil, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    func freeze() {
        guard !isFrozen else { return }
        isFrozen = true
        CGAssociateMouseAndMouseCursorPosition(0)
        CGDisplayHideCursor(CGMainDisplayID())
    }

    func thaw() {
        guard isFrozen else { return }
        isFrozen = false
        suppressClicksUntil = ProcessInfo.processInfo.systemUptime + 0.15
        CGAssociateMouseAndMouseCursorPosition(1)
        CGDisplayShowCursor(CGMainDisplayID())
    }

    fileprivate func handle(_ type: CGEventType, _ event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return Unmanaged.passUnretained(event)
        }
        if isFrozen { return nil }
        if ProcessInfo.processInfo.systemUptime < suppressClicksUntil, type != .mouseMoved { return nil }
        return Unmanaged.passUnretained(event)
    }
}

private let cursorTapCallback: CGEventTapCallBack = { _, type, event, info in
    guard let info else { return Unmanaged.passUnretained(event) }
    let freezer = Unmanaged<CursorFreezer>.fromOpaque(info).takeUnretainedValue()
    return freezer.handle(type, event)
}

// MARK: - Modifier state

enum Modifiers {
    static var current: CGEventFlags { CGEventSource.flagsState(.combinedSessionState) }
    static var fineControlHeld: Bool { current.contains(.maskShift) && current.contains(.maskAlternate) }

    static func isHeld(_ required: RequiredModifier) -> Bool {
        switch required {
        case .noModifier: true
        case .fn: current.contains(.maskSecondaryFn)
        case .option: current.contains(.maskAlternate)
        }
    }
}

// MARK: - Permissions

enum Permissions {
    static var accessibilityGranted: Bool { AXIsProcessTrusted() }

    static func requestAccessibility() {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        _ = AXIsProcessTrustedWithOptions([key: true] as CFDictionary)
    }

    static func openAccessibilitySettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }
}
