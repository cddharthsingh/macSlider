import AppKit
import AudioToolbox
import CoreAudio
import SwiftUI

// MARK: - Writers

/// Sets the output volume absolutely. Used by `LevelMode.direct`.
enum VolumeWriter {
    private static var address = AudioObjectPropertyAddress(
        mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
        mScope: kAudioDevicePropertyScopeOutput,
        mElement: kAudioObjectPropertyElementMain)
    private static var muteAddress = AudioObjectPropertyAddress(
        mSelector: kAudioDevicePropertyMute,
        mScope: kAudioDevicePropertyScopeOutput,
        mElement: kAudioObjectPropertyElementMain)

    private static var defaultDevice: AudioObjectID {
        var id = AudioObjectID(kAudioObjectUnknown)
        var size = UInt32(MemoryLayout<AudioObjectID>.size)
        var addr = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDefaultOutputDevice,
                                              mScope: kAudioObjectPropertyScopeGlobal,
                                              mElement: kAudioObjectPropertyElementMain)
        AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &size, &id)
        return id
    }

    static var isSupported: Bool { AudioObjectHasProperty(defaultDevice, &address) }

    @discardableResult
    static func set(_ level: Float) -> Bool {
        var v = min(max(level, 0), 1)
        let size = UInt32(MemoryLayout<Float32>.size)
        let device = defaultDevice
        guard AudioObjectSetPropertyData(device, &address, 0, nil, size, &v) == noErr else { return false }
        if v > 0 { var off: UInt32 = 0; AudioObjectSetPropertyData(device, &muteAddress, 0, nil, 4, &off) }
        return true
    }

    static func setMuted(_ muted: Bool) {
        var m: UInt32 = muted ? 1 : 0
        AudioObjectSetPropertyData(defaultDevice, &muteAddress, 0, nil, 4, &m)
    }
}

/// Sets built-in display brightness absolutely via the private DisplayServices framework.
enum BrightnessWriter {
    private typealias SetFn = @convention(c) (CGDirectDisplayID, Float) -> Int32
    private static let setBrightness: SetFn? = {
        let path = "/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices"
        guard let h = dlopen(path, RTLD_NOW), let p = dlsym(h, "DisplayServicesSetBrightness") else { return nil }
        return unsafeBitCast(p, to: SetFn.self)
    }()

    static var isSupported: Bool { setBrightness != nil }

    @discardableResult
    static func set(_ level: Float) -> Bool {
        guard let setBrightness else { return false }
        return setBrightness(CGMainDisplayID(), min(max(level, 0), 1)) == 0
    }
}

// MARK: - HUD

enum HUDKind { case volume, brightness, muted }

/// A small floating Liquid Glass panel shown while sliding in Direct mode.
/// Sits at the bottom centre of the main screen, like Apple's own HUD.
@MainActor
final class GlassHUD {
    static let shared = GlassHUD()

    private var panel: NSPanel?
    private var model = HUDModel()
    private var hideWork: DispatchWorkItem?

    func show(_ kind: HUDKind, level: Float) {
        model.kind = kind
        model.level = level
        if panel == nil { makePanel() }
        guard let panel, let screen = NSScreen.main else { return }
        let size = NSSize(width: 220, height: 64)
        let origin = NSPoint(x: screen.visibleFrame.midX - size.width / 2, y: screen.visibleFrame.minY + 80)
        panel.setFrame(NSRect(origin: origin, size: size), display: true)
        panel.alphaValue = 1
        panel.orderFrontRegardless()

        hideWork?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.fadeOut() }
        hideWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.1, execute: work)
    }

    private func fadeOut() {
        guard let panel else { return }
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.25
            panel.animator().alphaValue = 0
        }, completionHandler: { panel.orderOut(nil) })
    }

    private func makePanel() {
        let p = NSPanel(contentRect: .zero,
                        styleMask: [.borderless, .nonactivatingPanel, .hudWindow],
                        backing: .buffered, defer: false)
        p.level = .screenSaver
        p.isOpaque = false
        p.backgroundColor = .clear
        p.hasShadow = false
        p.ignoresMouseEvents = true
        p.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        p.contentView = NSHostingView(rootView: HUDView(model: model))
        panel = p
    }
}

@Observable
final class HUDModel {
    var kind: HUDKind = .volume
    var level: Float = 0
}

struct HUDView: View {
    let model: HUDModel

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 18, weight: .semibold))
                .frame(width: 24)
                .contentTransition(.symbolEffect(.replace))
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(.primary.opacity(0.12))
                    Capsule()
                        .fill(fill)
                        .frame(width: max(8, geo.size.width * CGFloat(model.level)))
                }
            }
            .frame(height: 8)
            Text("\(Int((model.level * 100).rounded()))")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .frame(width: 28, alignment: .trailing)
        }
        .padding(.horizontal, 16)
        .frame(width: 220, height: 64)
        .glassSurface(cornerRadius: 20)
        .animation(.easeOut(duration: 0.12), value: model.level)
    }

    private var symbol: String {
        switch model.kind {
        case .brightness: "sun.max.fill"
        case .muted: "speaker.slash.fill"
        case .volume:
            model.level == 0 ? "speaker.fill" : model.level < 0.34 ? "speaker.wave.1.fill" : model.level < 0.67 ? "speaker.wave.2.fill" : "speaker.wave.3.fill"
        }
    }

    private var fill: LinearGradient {
        switch model.kind {
        case .brightness: LinearGradient(colors: [.orange, .yellow], startPoint: .leading, endPoint: .trailing)
        case .muted: LinearGradient(colors: [.red, .pink], startPoint: .leading, endPoint: .trailing)
        case .volume: LinearGradient(colors: [.indigo, .cyan], startPoint: .leading, endPoint: .trailing)
        }
    }
}
