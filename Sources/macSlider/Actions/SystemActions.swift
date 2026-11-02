import AppKit
import AudioToolbox
import CoreAudio
import CoreGraphics
import Foundation

// MARK: - Media keys

/// Key codes from <IOKit/hidsystem/ev_keymap.h>. Posting these as system-defined events
/// makes macOS behave exactly as if the physical key was pressed, including its HUD.
enum MediaKey: Int32 {
    case soundUp = 0
    case soundDown = 1
    case brightnessUp = 2
    case brightnessDown = 3
    case mute = 7
    case play = 16
    case next = 17
    case previous = 18
    case illuminationUp = 21
    case illuminationDown = 22

    /// Press and release the key. `fine` adds Shift+Option, which macOS interprets as a
    /// quarter step for volume and brightness.
    func press(fine: Bool = false) {
        for isDown in [true, false] {
            var flags: UInt = isDown ? 0xA00 : 0xB00
            if fine { flags |= NSEvent.ModifierFlags.shift.rawValue | NSEvent.ModifierFlags.option.rawValue }
            let data1 = Int((rawValue << 16) | ((isDown ? 0xA : 0xB) << 8))
            let event = NSEvent.otherEvent(with: .systemDefined,
                                           location: .zero,
                                           modifierFlags: NSEvent.ModifierFlags(rawValue: flags),
                                           timestamp: ProcessInfo.processInfo.systemUptime,
                                           windowNumber: 0,
                                           context: nil,
                                           subtype: 8,
                                           data1: data1,
                                           data2: -1)
            event?.cgEvent?.post(tap: .cghidEventTap)
        }
    }
}

// MARK: - Keyboard shortcuts

enum KeyPress {
    /// Virtual key codes from Carbon's Events.h.
    static let leftArrow: CGKeyCode = 123
    static let rightArrow: CGKeyCode = 124
    static let upArrow: CGKeyCode = 126
    static let f11: CGKeyCode = 103
    static let q: CGKeyCode = 12

    static func post(_ key: CGKeyCode, flags: CGEventFlags = []) {
        let source = CGEventSource(stateID: .hidSystemState)
        guard let down = CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: true),
              let up = CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: false) else { return }
        down.flags = flags
        up.flags = flags
        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
    }

    static func missionControl() { post(upArrow, flags: .maskControl) }
    static func showDesktop() { post(f11, flags: .maskSecondaryFn) }
    static func lockScreen() { post(q, flags: [.maskControl, .maskCommand]) }
    static func switchSpace(direction: Int) { post(direction > 0 ? rightArrow : leftArrow, flags: .maskControl) }
}

// MARK: - Shortcuts.app

enum ShortcutsRunner {
    static func run(_ name: String) {
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/shortcuts")
        p.arguments = ["run", name]
        try? p.run()
    }
}

// MARK: - Live volume (read side, for the UI)

/// Reads the output volume and mute state through CoreAudio and publishes changes.
final class VolumeMonitor {
    var onChange: ((Float, Bool) -> Void)?
    private(set) var level: Float = 0
    private(set) var isMuted = false
    private var device = AudioObjectID(kAudioObjectUnknown)

    private var volumeAddress = AudioObjectPropertyAddress(
        mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
        mScope: kAudioDevicePropertyScopeOutput,
        mElement: kAudioObjectPropertyElementMain)
    private var muteAddress = AudioObjectPropertyAddress(
        mSelector: kAudioDevicePropertyMute,
        mScope: kAudioDevicePropertyScopeOutput,
        mElement: kAudioObjectPropertyElementMain)
    private var defaultDeviceAddress = AudioObjectPropertyAddress(
        mSelector: kAudioHardwarePropertyDefaultOutputDevice,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain)

    init() {
        attach()
        AudioObjectAddPropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &defaultDeviceAddress, .main) { [weak self] _, _ in
            self?.attach()
        }
    }

    private func attach() {
        var id = AudioObjectID(kAudioObjectUnknown)
        var size = UInt32(MemoryLayout<AudioObjectID>.size)
        AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &defaultDeviceAddress, 0, nil, &size, &id)
        guard id != device else { refresh(); return }
        device = id
        AudioObjectAddPropertyListenerBlock(device, &volumeAddress, .main) { [weak self] _, _ in self?.refresh() }
        AudioObjectAddPropertyListenerBlock(device, &muteAddress, .main) { [weak self] _, _ in self?.refresh() }
        refresh()
    }

    func refresh() {
        var vol: Float32 = 0
        var size = UInt32(MemoryLayout<Float32>.size)
        if AudioObjectGetPropertyData(device, &volumeAddress, 0, nil, &size, &vol) == noErr { level = vol }

        var muted: UInt32 = 0
        size = UInt32(MemoryLayout<UInt32>.size)
        if AudioObjectGetPropertyData(device, &muteAddress, 0, nil, &size, &muted) == noErr { isMuted = muted != 0 }

        onChange?(level, isMuted)
    }
}

// MARK: - Live brightness (read side, for the UI)

/// Reads built-in display brightness via the private DisplayServices framework.
/// Falls back to nil when unavailable (for example on a Mac mini with no internal display).
final class BrightnessMonitor {
    private typealias GetFn = @convention(c) (CGDirectDisplayID, UnsafeMutablePointer<Float>) -> Int32
    private var getBrightness: GetFn?

    init() {
        let path = "/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices"
        guard let h = dlopen(path, RTLD_NOW), let p = dlsym(h, "DisplayServicesGetBrightness") else { return }
        getBrightness = unsafeBitCast(p, to: GetFn.self)
    }

    var level: Float? {
        guard let getBrightness else { return nil }
        var value: Float = 0
        return getBrightness(CGMainDisplayID(), &value) == 0 ? value : nil
    }
}
