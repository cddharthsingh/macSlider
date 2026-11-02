import Foundation

/// A single finger contact, normalized to the device surface. Origin is bottom-left.
public struct Touch: Identifiable, Equatable {
    public let id: Int32
    public let x: CGFloat
    public let y: CGFloat
    public let pressure: CGFloat
    public let isDown: Bool

    public init(id: Int32, x: CGFloat, y: CGFloat, pressure: CGFloat, isDown: Bool) {
        self.id = id; self.x = x; self.y = y; self.pressure = pressure; self.isDown = isDown
    }
}

public enum TouchDeviceKind {
    case builtInTrackpad
    case externalTrackpad
    case magicMouse
}

public struct TouchFrame {
    public let device: TouchDeviceKind
    public let touches: [Touch]
    public let timestamp: TimeInterval

    public init(device: TouchDeviceKind, touches: [Touch], timestamp: TimeInterval) {
        self.device = device; self.touches = touches; self.timestamp = timestamp
    }
}
