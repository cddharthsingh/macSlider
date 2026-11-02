import AppKit
import macSliderCore
import Foundation
import MultitouchBridge

/// Streams raw multitouch frames from every attached trackpad (and optionally Magic Mouse)
/// by loading Apple's private MultitouchSupport framework at runtime.
///
/// Nothing in the app links against the framework, so the project builds with a stock SDK.
/// If the symbols ever change, `isAvailable` becomes false and the app degrades gracefully.
final class MultitouchService {
    static let shared = MultitouchService()

    var onFrame: ((TouchFrame) -> Void)?
    var includeMagicMouse = false { didSet { if includeMagicMouse != oldValue { restart() } } }

    private(set) var isAvailable = false
    private(set) var deviceCount = 0

    private var handle: UnsafeMutableRawPointer?
    private var devices: [UnsafeMutableRawPointer: TouchDeviceKind] = [:]
    private var retainedList: CFArray?
    private var watchdog: Timer?

    // MARK: Private symbols

    private typealias CreateListFn = @convention(c) () -> Unmanaged<CFArray>?
    private typealias RegisterFn = @convention(c) (MTDeviceRef?, MTFrameCallback?) -> Void
    private typealias StartFn = @convention(c) (MTDeviceRef?, Int32) -> Void
    private typealias StopFn = @convention(c) (MTDeviceRef?) -> Void
    private typealias IsBuiltInFn = @convention(c) (MTDeviceRef?) -> Bool
    private typealias FamilyIDFn = @convention(c) (MTDeviceRef?, UnsafeMutablePointer<Int32>?) -> Int32
    private typealias DeviceIDFn = @convention(c) (MTDeviceRef?, UnsafeMutablePointer<UInt64>?) -> Int32

    private var createList: CreateListFn?
    private var register: RegisterFn?
    private var start: StartFn?
    private var stop: StopFn?
    private var isBuiltIn: IsBuiltInFn?
    private var familyID: FamilyIDFn?
    private var deviceID: DeviceIDFn?

    /// Device IDs are needed by the haptic actuator.
    private(set) var builtInDeviceID: UInt64?

    private init() {
        loadSymbols()
        observeSystem()
    }

    private func loadSymbols() {
        let path = "/System/Library/PrivateFrameworks/MultitouchSupport.framework/MultitouchSupport"
        guard let h = dlopen(path, RTLD_NOW) else { return }
        handle = h

        func sym<T>(_ name: String, as _: T.Type) -> T? {
            guard let p = dlsym(h, name) else { return nil }
            return unsafeBitCast(p, to: T.self)
        }

        createList = sym("MTDeviceCreateList", as: CreateListFn.self)
        register = sym("MTRegisterContactFrameCallback", as: RegisterFn.self)
        start = sym("MTDeviceStart", as: StartFn.self)
        stop = sym("MTDeviceStop", as: StopFn.self)
        isBuiltIn = sym("MTDeviceIsBuiltIn", as: IsBuiltInFn.self)
        familyID = sym("MTDeviceGetFamilyID", as: FamilyIDFn.self)
        deviceID = sym("MTDeviceGetDeviceID", as: DeviceIDFn.self)

        isAvailable = createList != nil && register != nil && start != nil
    }

    // MARK: Lifecycle

    func startListening() {
        guard isAvailable, devices.isEmpty else { return }
        guard let list = createList?()?.takeRetainedValue() else { return }
        retainedList = list

        for i in 0 ..< CFArrayGetCount(list) {
            guard let raw = CFArrayGetValueAtIndex(list, i) else { continue }
            let ref = UnsafeMutableRawPointer(mutating: raw)
            let kind = classify(ref)
            if kind == .magicMouse, !includeMagicMouse { continue }

            if kind == .builtInTrackpad {
                var id: UInt64 = 0
                if deviceID?(ref, &id) == 0 { builtInDeviceID = id }
            }

            devices[ref] = kind
            register?(ref, frameCallback)
            start?(ref, 0)
        }
        deviceCount = devices.count
        startWatchdog()
    }

    func stopListening() {
        for (ref, _) in devices { stop?(ref) }
        devices.removeAll()
        retainedList = nil
        deviceCount = 0
        watchdog?.invalidate()
        watchdog = nil
    }

    func restart() {
        stopListening()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.startListening()
        }
    }

    private func classify(_ ref: UnsafeMutableRawPointer) -> TouchDeviceKind {
        if isBuiltIn?(ref) == true { return .builtInTrackpad }
        var family: Int32 = 0
        _ = familyID?(ref, &family)
        // Magic Mouse 1/2 report family IDs 112 and 113. Magic Trackpads report 128 and up.
        if (112 ... 113).contains(family) { return .magicMouse }
        return .externalTrackpad
    }

    // MARK: Recovery

    private func observeSystem() {
        let nc = NSWorkspace.shared.notificationCenter
        nc.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            self?.restart()
        }
        nc.addObserver(forName: NSWorkspace.screensDidWakeNotification, object: nil, queue: .main) { [weak self] _ in
            self?.restart()
        }
    }

    /// Cheap periodic check: if the number of multitouch devices changed (Magic Trackpad
    /// plugged in, Bluetooth reconnect) rebuild the subscriptions.
    private func startWatchdog() {
        watchdog?.invalidate()
        watchdog = Timer.scheduledTimer(withTimeInterval: 4, repeats: true) { [weak self] _ in
            guard let self, let list = self.createList?()?.takeRetainedValue() else { return }
            var expected = 0
            for i in 0 ..< CFArrayGetCount(list) {
                guard let raw = CFArrayGetValueAtIndex(list, i) else { continue }
                let kind = self.classify(UnsafeMutableRawPointer(mutating: raw))
                if kind != .magicMouse || self.includeMagicMouse { expected += 1 }
            }
            if expected != self.devices.count { self.restart() }
        }
    }

    // MARK: Frame delivery

    fileprivate func deliver(device: MTDeviceRef?, touches: UnsafeMutablePointer<MTTouch>?, count: Int32, timestamp: Double) {
        guard let device, let kind = devices[device] else { return }
        var result: [Touch] = []
        if let touches, count > 0 {
            result.reserveCapacity(Int(count))
            for i in 0 ..< Int(count) {
                let t = touches[i]
                let down = t.state == 3 || t.state == 4 // MTTouchStateMakeTouch / MTTouchStateTouching
                result.append(Touch(id: t.identifier,
                                    x: CGFloat(t.normalized.position.x),
                                    y: CGFloat(t.normalized.position.y),
                                    pressure: CGFloat(t.total),
                                    isDown: down))
            }
        }
        let frame = TouchFrame(device: kind, touches: result, timestamp: timestamp)
        onFrame?(frame)
    }
}

/// C callback trampoline. MultitouchSupport calls this on its own thread.
private let frameCallback: MTFrameCallback = { device, touches, count, timestamp, _ in
    MultitouchService.shared.deliver(device: device, touches: touches, count: count, timestamp: timestamp)
    return 0
}
