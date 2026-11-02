import XCTest
@testable import macSliderCore

final class GestureEngineTests: XCTestCase {
    private var engine: GestureEngine!
    private var events: [GestureEvent]!

    override func setUp() {
        engine = GestureEngine()
        engine.config.stepDistance = 0.05
        events = []
        engine.onEvent = { [unowned self] in events.append($0) }
    }

    private func frame(_ touches: [(CGFloat, CGFloat)], t: TimeInterval, id: Int32 = 1) -> TouchFrame {
        TouchFrame(device: .builtInTrackpad,
                   touches: touches.enumerated().map { i, p in
                       Touch(id: id + Int32(i), x: p.0, y: p.1, pressure: 1, isDown: true)
                   },
                   timestamp: t)
    }

    private func lift(t: TimeInterval) -> TouchFrame {
        TouchFrame(device: .builtInTrackpad, touches: [], timestamp: t)
    }

    func testRightEdgeSlideUpEmitsPositiveSteps() {
        engine.process(frame([(0.97, 0.30)], t: 0))
        engine.process(frame([(0.97, 0.36)], t: 0.02))
        engine.process(frame([(0.97, 0.46)], t: 0.04))

        guard case .slideBegan(.right) = events[0] else { return XCTFail("expected slideBegan, got \(events!)") }
        let steps = events.compactMap { if case .slideStep(.right, let n) = $0 { n } else { nil } }.reduce(0, +)
        XCTAssertEqual(steps, 3)
    }

    func testLeftEdgeSlideDownEmitsNegativeSteps() {
        engine.process(frame([(0.03, 0.80)], t: 0))
        engine.process(frame([(0.03, 0.65)], t: 0.02))

        let steps = events.compactMap { if case .slideStep(.left, let n) = $0 { n } else { nil } }.reduce(0, +)
        XCTAssertEqual(steps, -3)
    }

    func testTouchStartingInTheMiddleIsIgnored() {
        engine.process(frame([(0.5, 0.5)], t: 0))
        engine.process(frame([(0.5, 0.9)], t: 0.1))
        engine.process(lift(t: 0.2))
        XCTAssertTrue(events.isEmpty)
    }

    func testSecondFingerCancelsSlide() {
        engine.process(frame([(0.97, 0.30)], t: 0))
        engine.process(frame([(0.97, 0.40)], t: 0.02))
        engine.process(frame([(0.97, 0.45), (0.5, 0.5)], t: 0.04))

        guard case .slideEnded(.right) = events.last else { return XCTFail("expected slideEnded, got \(events!)") }
        let before = events.count
        engine.process(frame([(0.97, 0.60), (0.5, 0.6)], t: 0.06))
        XCTAssertEqual(events.count, before, "no events while two fingers are down")
    }

    func testBottomStripSwipeRight() {
        engine.process(frame([(0.30, 0.02)], t: 0))
        engine.process(frame([(0.45, 0.02)], t: 0.05))
        engine.process(frame([(0.60, 0.02)], t: 0.10))
        engine.process(lift(t: 0.15))

        XCTAssertTrue(events.contains { if case .swipe(.bottom, 1) = $0 { true } else { false } })
    }

    func testBottomPortionOnlyRejectsUpperEdge() {
        engine.config.bottomPortionOnly = true
        engine.process(frame([(0.97, 0.80)], t: 0))
        engine.process(frame([(0.97, 0.95)], t: 0.02))
        XCTAssertTrue(events.isEmpty)

        engine.process(lift(t: 0.1))
        engine.process(frame([(0.97, 0.18)], t: 0.2))
        engine.process(frame([(0.97, 0.24)], t: 0.22))
        XCTAssertFalse(events.isEmpty)
    }

    func testSlideStartingInACornerFallsThroughToTheEdge() {
        engine.process(frame([(0.97, 0.05)], t: 0))      // bottom-right corner, also right edge
        engine.process(frame([(0.97, 0.12)], t: 0.02))   // too far for a tap
        engine.process(frame([(0.97, 0.22)], t: 0.04))

        XCTAssertTrue(events.contains { if case .slideBegan(.right) = $0 { true } else { false } })
    }

    func testCornerDoubleTap() {
        engine.process(frame([(0.95, 0.95)], t: 0))
        engine.process(lift(t: 0.08))
        engine.process(frame([(0.95, 0.95)], t: 0.20))
        engine.process(lift(t: 0.28))

        XCTAssertTrue(events.contains { if case .doubleTap(.topRight) = $0 { true } else { false } })
    }

    func testSlowSecondTapIsNotADoubleTap() {
        engine.process(frame([(0.95, 0.95)], t: 0))
        engine.process(lift(t: 0.08))
        engine.process(frame([(0.95, 0.95)], t: 1.0))
        engine.process(lift(t: 1.08))

        XCTAssertFalse(events.contains { if case .doubleTap = $0 { true } else { false } })
        XCTAssertEqual(events.filter { if case .tap = $0 { true } else { false } }.count, 2)
    }

    func testRequiredModifierBlocksSlide() {
        engine.config.requireModifier = { false }
        engine.process(frame([(0.97, 0.30)], t: 0))
        engine.process(frame([(0.97, 0.50)], t: 0.02))
        XCTAssertTrue(events.isEmpty)
    }

    func testSlideSurvivesBriefContactLoss() {
        engine.process(frame([(0.97, 0.30)], t: 0))
        engine.process(frame([(0.97, 0.40)], t: 0.02))
        engine.process(lift(t: 0.04))
        engine.process(frame([(0.97, 0.42)], t: 0.08))  // back within the grace window
        engine.process(frame([(0.97, 0.50)], t: 0.10))

        let began = events.filter { if case .slideBegan = $0 { true } else { false } }.count
        XCTAssertEqual(began, 1, "a resumed slide must not begin again")
        let ended = events.filter { if case .slideEnded = $0 { true } else { false } }.count
        XCTAssertEqual(ended, 0)
    }
}
