import Foundation

public enum Edge: String, Codable, CaseIterable { case left, right, top, bottom }
public enum Corner: String, Codable, CaseIterable { case topLeft, topRight, bottomLeft, bottomRight }

public enum GestureEvent {
    /// A finger started sliding along an edge.
    case slideBegan(Edge)
    /// The finger moved far enough for `steps` discrete steps. Positive is up / right.
    case slideStep(Edge, steps: Int)
    case slideEnded(Edge)
    /// Horizontal flick along the bottom or top strip, reported on lift. `direction` is -1 (left) or +1 (right).
    case swipe(Edge, direction: Int)
    case tap(Corner)
    case doubleTap(Corner)
}

/// Everything the engine needs to know about where zones are. Built from `Settings`.
public struct ZoneConfig {
    public var edgeWidth: CGFloat = 0.07          // fraction of the surface that counts as an edge
    public var cornerSize: CGFloat = 0.16
    public var bottomPortionOnly: Bool = false    // only lower 25% of left/right edges respond
    public var stepDistance: CGFloat = 0.045      // normalized travel per step (sensitivity)
    public var topStepDistance: CGFloat = 0.045   // the top strip gets its own pacing
    public var verticalEdgesEnabled = true
    public var bottomStripEnabled = true
    public var topStripEnabled = false
    public var cornersEnabled = true
    public var requireModifier: () -> Bool = { true }

    public init() {}
}

/// Converts frames of touches into high-level gestures.
///
/// Design: a tiny state machine per surface. Only single-finger contacts are considered,
/// so two-finger scrolling and system gestures never collide with it.
public final class GestureEngine {
    public var config = ZoneConfig()
    public var onEvent: ((GestureEvent) -> Void)?

    private enum Phase {
        case idle
        case candidate(start: Touch, startTime: TimeInterval, zone: Zone)
        case sliding(edge: Edge, accumulator: CGFloat, last: Touch, totalTravel: CGFloat)
        case pendingEnd(edge: Edge, accumulator: CGFloat, endedAt: TimeInterval)
    }

    private enum Zone: Equatable {
        case edge(Edge)
        case corner(Corner)
    }

    private var phase: Phase = .idle
    private var lastTap: (corner: Corner, time: TimeInterval)?
    private var endTimer: DispatchWorkItem?

    public init() {}

    private let swipeMinTravel: CGFloat = 0.18
    private let tapMaxTravel: CGFloat = 0.03
    private let tapMaxDuration: TimeInterval = 0.25
    private let doubleTapWindow: TimeInterval = 0.35
    private let slideGrace: TimeInterval = 0.14
    private let slideActivation: CGFloat = 0.02

    public func process(_ frame: TouchFrame) {
        let fingers = frame.touches.filter(\.isDown)

        // Multi-finger input belongs to the system. Abort anything in progress.
        if fingers.count > 1 {
            if case .sliding(let edge, _, _, _) = phase { onEvent?(.slideEnded(edge)) }
            phase = .idle
            return
        }

        guard let finger = fingers.first else {
            fingerLifted(at: frame.timestamp)
            return
        }

        switch phase {
        case .idle:
            guard config.requireModifier(), let zone = zone(for: finger) else { return }
            phase = .candidate(start: finger, startTime: frame.timestamp, zone: zone)

        case .candidate(let start, let startTime, let zone):
            let dx = finger.x - start.x
            let dy = finger.y - start.y
            switch zone {
            case .edge(let edge):
                let primary = isVertical(edge) ? dy : dx
                let secondary = isVertical(edge) ? dx : dy
                if abs(primary) >= slideActivation, abs(primary) > abs(secondary) * 0.8 {
                    onEvent?(.slideBegan(edge))
                    phase = .sliding(edge: edge, accumulator: 0, last: finger, totalTravel: 0)
                    advance(edge: edge, delta: primary, finger: finger)
                } else if abs(secondary) > slideActivation * 2 {
                    // Moved away from the edge: this is normal pointer use.
                    phase = .idle
                }
            case .corner:
                guard hypot(dx, dy) > tapMaxTravel else { return }
                // Not a tap. If the corner also lies on an edge band, hand over to the edge
                // so a slide that starts low on the right edge still controls volume.
                if let edgeZone = self.zone(for: start, ignoringCorners: true) {
                    phase = .candidate(start: start, startTime: startTime, zone: edgeZone)
                    process(frame)
                } else {
                    phase = .idle
                }
            }

        case .sliding(let edge, _, let last, _):
            let delta = isVertical(edge) ? finger.y - last.y : finger.x - last.x
            advance(edge: edge, delta: delta, finger: finger)

        case .pendingEnd(let edge, let accumulator, _):
            // Finger came back within the grace window: resume the same slide.
            endTimer?.cancel()
            phase = .sliding(edge: edge, accumulator: accumulator, last: finger, totalTravel: 0)
        }
    }

    // MARK: Internals

    private func advance(edge: Edge, delta: CGFloat, finger: Touch) {
        guard case .sliding(_, var acc, _, var travel) = phase else { return }
        acc += delta
        travel += delta

        let stepDistance = edge == .top ? config.topStepDistance : config.stepDistance
        var steps = 0
        while acc >= stepDistance { acc -= stepDistance; steps += 1 }
        while acc <= -stepDistance { acc += stepDistance; steps -= 1 }
        if steps != 0 { onEvent?(.slideStep(edge, steps: steps)) }
        phase = .sliding(edge: edge, accumulator: acc, last: finger, totalTravel: travel)
    }

    private func fingerLifted(at time: TimeInterval) {
        switch phase {
        case .idle, .pendingEnd:
            return

        case .candidate(_, let startTime, let zone):
            phase = .idle
            guard case .corner(let corner) = zone, time - startTime <= tapMaxDuration else { return }
            if let last = lastTap, last.corner == corner, time - last.time <= doubleTapWindow {
                lastTap = nil
                onEvent?(.doubleTap(corner))
            } else {
                lastTap = (corner, time)
                onEvent?(.tap(corner))
            }

        case .sliding(let edge, let acc, _, let travel):
            if !isVertical(edge), abs(travel) >= swipeMinTravel {
                phase = .idle
                onEvent?(.slideEnded(edge))
                onEvent?(.swipe(edge, direction: travel > 0 ? 1 : -1))
                return
            }
            // Keep the slide alive briefly so a lost contact does not end it.
            phase = .pendingEnd(edge: edge, accumulator: acc, endedAt: time)
            let work = DispatchWorkItem { [weak self] in
                guard let self, case .pendingEnd(let e, _, _) = self.phase else { return }
                self.phase = .idle
                self.onEvent?(.slideEnded(e))
            }
            endTimer = work
            DispatchQueue.main.asyncAfter(deadline: .now() + slideGrace, execute: work)
        }
    }

    private func isVertical(_ edge: Edge) -> Bool { edge == .left || edge == .right }

    private func zone(for t: Touch, ignoringCorners: Bool = false) -> Zone? {
        let w = config.edgeWidth
        let c = config.cornerSize

        if config.cornersEnabled, !ignoringCorners {
            if t.x <= c, t.y >= 1 - c { return .corner(.topLeft) }
            if t.x >= 1 - c, t.y >= 1 - c { return .corner(.topRight) }
            if t.x <= c, t.y <= c { return .corner(.bottomLeft) }
            if t.x >= 1 - c, t.y <= c { return .corner(.bottomRight) }
        }

        let verticalOK = !config.bottomPortionOnly || t.y <= 0.25
        if config.verticalEdgesEnabled, verticalOK {
            if t.x <= w { return .edge(.left) }
            if t.x >= 1 - w { return .edge(.right) }
        }
        if config.bottomStripEnabled, t.y <= w { return .edge(.bottom) }
        if config.topStripEnabled, t.y >= 1 - w { return .edge(.top) }
        return nil
    }
}
