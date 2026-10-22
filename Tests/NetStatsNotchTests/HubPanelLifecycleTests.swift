import XCTest
@testable import NetStatsCore

final class HubPanelLifecycleTests: XCTestCase {
    func testTypingHoldsExpandedCardUntilInteractionEnds() {
        var state = HubHoverLifecycle()
        state.update(now: 0, inTrigger: true, inCard: false)
        state.update(now: 1, inTrigger: true, inCard: false)
        state.update(now: 2, inTrigger: false, inCard: false, held: true)
        state.update(now: 30, inTrigger: false, inCard: false, held: true)
        XCTAssertTrue(state.isVisible)
        XCTAssertNil(state.nextDeadline)
        state.update(now: 31, inTrigger: false, inCard: false)
        XCTAssertEqual(state.nextDeadline, 31.3)
        state.update(now: 31.3, inTrigger: false, inCard: false)
        XCTAssertFalse(state.isVisible)
    }

    func testInteractionHoldCannotOpenClosedCard() {
        var state = HubHoverLifecycle()
        state.update(now: 10, inTrigger: false, inCard: false, held: true)
        XCTAssertFalse(state.isVisible)
        XCTAssertNil(state.nextDeadline)
    }

    func testFileDragExpansionBypassesOrdinaryDwellAndRemainsWhileDragging() {
        var state = HubHoverLifecycle()
        state.expandForFileDrag()
        state.update(now: 5, inTrigger: false, inCard: false, pointerDown: true, held: true)
        XCTAssertTrue(state.isVisible)
        XCTAssertNil(state.nextDeadline)
        state.update(now: 6, inTrigger: false, inCard: false)
        XCTAssertEqual(state.nextDeadline, 6.3)
    }

    func testDismissRequiresExitEvenIfInteractionHadBeenHeld() {
        var state = HubHoverLifecycle()
        state.expandForFileDrag()
        state.dismiss()
        state.update(now: 0, inTrigger: true, inCard: false, held: true)
        state.update(now: 10, inTrigger: true, inCard: false)
        XCTAssertFalse(state.isVisible)
        state.update(now: 11, inTrigger: false, inCard: false)
        state.update(now: 12, inTrigger: true, inCard: false)
        XCTAssertEqual(state.nextDeadline, 13)
    }

    func testHoldCancelsPendingCloseAndFreshGraceStartsOnRelease() {
        var state = HubHoverLifecycle()
        state.expandForFileDrag()
        state.update(now: 5, inTrigger: false, inCard: false)
        state.update(now: 5.2, inTrigger: false, inCard: false, held: true)
        XCTAssertNil(state.nextDeadline)
        state.update(now: 8, inTrigger: false, inCard: false)
        XCTAssertEqual(state.nextDeadline, 8.3)
    }

    func testSuppressionCancelsPendingDwell() {
        var state = HubHoverLifecycle()
        state.update(now: 0, inTrigger: true, inCard: false)
        state.update(now: 1, inTrigger: true, inCard: false, suppressed: true)
        XCTAssertFalse(state.isVisible)
        XCTAssertNil(state.nextDeadline)
    }

    func testFileDragDwellDoesNotResetWithinDestination() {
        var state = NotchFileDragDwell()
        state.enter(now: 10)
        state.enter(now: 10.3)
        XCTAssertEqual(state.deadline, 10.5)
        XCTAssertFalse(state.isReady(now: 10.499))
        XCTAssertTrue(state.isReady(now: 10.5))
        state.exit()
        XCTAssertFalse(state.isReady(now: 11))
        state.enter(now: 12)
        XCTAssertEqual(state.deadline, 12.5)
    }
}
