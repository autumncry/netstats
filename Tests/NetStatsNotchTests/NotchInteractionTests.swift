import XCTest
@testable import NetStatsCore

final class NotchInteractionTests: XCTestCase {
    func testDwellOpensAtOneSecondAndDoesNotResetInside() {
        var interaction = NotchInteraction()
        XCTAssertEqual(interaction.phase, .closed)
        XCTAssertNil(interaction.nextDeadline)
        interaction.update(now: 10, inTrigger: true, inCard: false)
        XCTAssertEqual(interaction.phase, .waitingToOpen)
        XCTAssertEqual(interaction.nextDeadline, 11)
        interaction.update(now: 10.999, inTrigger: true, inCard: false)
        XCTAssertFalse(interaction.isVisible)
        XCTAssertEqual(interaction.nextDeadline, 11)
        interaction.update(now: 11, inTrigger: true, inCard: false)
        XCTAssertEqual(interaction.phase, .expanded)
        XCTAssertTrue(interaction.isVisible)
        XCTAssertNil(interaction.nextDeadline)
    }

    func testShortExitCancelsAndReentryRequiresFullDwell() {
        var interaction = NotchInteraction()
        interaction.update(now: 0, inTrigger: true, inCard: false)
        interaction.update(now: 0.9, inTrigger: false, inCard: false)
        XCTAssertEqual(interaction.phase, .closed)
        XCTAssertNil(interaction.nextDeadline)
        interaction.update(now: 0.95, inTrigger: true, inCard: false)
        XCTAssertEqual(interaction.nextDeadline, 1.95)
        interaction.update(now: 1, inTrigger: true, inCard: false)
        XCTAssertFalse(interaction.isVisible)
    }

    func testOpeningCallbackRechecksTriggerAtDeadline() {
        var interaction = NotchInteraction()
        interaction.update(now: 0, inTrigger: true, inCard: false)
        interaction.update(now: 1, inTrigger: false, inCard: true)
        XCTAssertEqual(interaction.phase, .closed)
        XCTAssertNil(interaction.nextDeadline)
    }

    func testCardAloneCannotStartOpening() {
        var interaction = NotchInteraction()
        interaction.update(now: 0, inTrigger: false, inCard: true)
        interaction.update(now: 2, inTrigger: false, inCard: true)
        XCTAssertEqual(interaction.phase, .closed)
    }

    func testExpandedRemainsOpenAcrossTriggerAndCard() {
        var interaction = opened()
        interaction.update(now: 2, inTrigger: false, inCard: true)
        XCTAssertEqual(interaction.phase, .expanded)
        interaction.update(now: 3, inTrigger: true, inCard: false)
        XCTAssertEqual(interaction.phase, .expanded)
        XCTAssertNil(interaction.nextDeadline)
    }

    func testExitGraceDoesNotExtendAndClosesAtDeadline() {
        var interaction = opened()
        interaction.update(now: 2, inTrigger: false, inCard: false)
        XCTAssertEqual(interaction.phase, .waitingToClose)
        XCTAssertTrue(interaction.isVisible)
        XCTAssertEqual(interaction.nextDeadline, 2.3)
        interaction.update(now: 2.299, inTrigger: false, inCard: false)
        XCTAssertEqual(interaction.nextDeadline, 2.3)
        XCTAssertTrue(interaction.isVisible)
        interaction.update(now: 2.3, inTrigger: false, inCard: false)
        XCTAssertEqual(interaction.phase, .closed)
        XCTAssertFalse(interaction.isVisible)
        XCTAssertNil(interaction.nextDeadline)
    }

    func testReentryCancelsGraceEvenAtOldDeadline() {
        for entersTrigger in [true, false] {
            var interaction = opened()
            interaction.update(now: 2, inTrigger: false, inCard: false)
            interaction.update(now: 2.3, inTrigger: entersTrigger, inCard: !entersTrigger)
            XCTAssertEqual(interaction.phase, .expanded)
            XCTAssertNil(interaction.nextDeadline)
            interaction.update(now: 3, inTrigger: false, inCard: false)
            XCTAssertEqual(interaction.nextDeadline, 3.3)
        }
    }

    func testDismissDuringPendingOpenRejectsStaleCallbackUntilExit() {
        var interaction = NotchInteraction()
        interaction.update(now: 0, inTrigger: true, inCard: false)
        interaction.dismiss()
        interaction.update(now: 1, inTrigger: true, inCard: false)
        XCTAssertEqual(interaction.phase, .closed)
        XCTAssertNil(interaction.nextDeadline)
        interaction.update(now: 2, inTrigger: false, inCard: false)
        interaction.update(now: 3, inTrigger: true, inCard: false)
        XCTAssertEqual(interaction.nextDeadline, 4)
    }

    func testDismissExpandedRequiresExitFromBothRegions() {
        var interaction = opened()
        interaction.dismiss()
        XCTAssertFalse(interaction.isVisible)
        interaction.update(now: 2, inTrigger: false, inCard: true)
        interaction.update(now: 3, inTrigger: true, inCard: false)
        XCTAssertEqual(interaction.phase, .closed)
        interaction.update(now: 4, inTrigger: false, inCard: false)
        interaction.update(now: 5, inTrigger: true, inCard: false)
        XCTAssertEqual(interaction.nextDeadline, 6)
    }

    func testDismissWithoutExitAllowsFreshDwell() {
        var interaction = opened()
        interaction.dismiss(requireExit: false)
        interaction.update(now: 2, inTrigger: true, inCard: false)
        XCTAssertEqual(interaction.phase, .waitingToOpen)
        XCTAssertEqual(interaction.nextDeadline, 3)
    }

    func testSuppressionClosesImmediatelyAndResumingInsideStaysGated() {
        var interaction = opened()
        interaction.update(now: 2, inTrigger: true, inCard: false, suppressed: true)
        XCTAssertEqual(interaction.phase, .closed)
        XCTAssertNil(interaction.nextDeadline)
        interaction.update(now: 3, inTrigger: true, inCard: false)
        interaction.update(now: 10, inTrigger: true, inCard: false)
        XCTAssertEqual(interaction.phase, .closed)
        interaction.update(now: 11, inTrigger: false, inCard: false)
        interaction.update(now: 12, inTrigger: true, inCard: false)
        XCTAssertEqual(interaction.nextDeadline, 13)
    }

    func testSuppressionOutsideClearsGateOnNextOutsideObservation() {
        var interaction = opened()
        interaction.update(now: 2, inTrigger: false, inCard: false, suppressed: true)
        interaction.update(now: 3, inTrigger: false, inCard: false)
        interaction.update(now: 4, inTrigger: true, inCard: false)
        XCTAssertEqual(interaction.nextDeadline, 5)
    }

    func testDraggingCannotStartOrCompletePendingOpen() {
        var interaction = NotchInteraction()
        interaction.update(now: 0, inTrigger: true, inCard: false, mouseDown: true)
        XCTAssertEqual(interaction.phase, .closed)
        interaction.update(now: 1, inTrigger: true, inCard: false)
        interaction.update(now: 2, inTrigger: true, inCard: false, mouseDown: true)
        XCTAssertEqual(interaction.phase, .closed)
        XCTAssertNil(interaction.nextDeadline)
        interaction.update(now: 3, inTrigger: true, inCard: false)
        XCTAssertEqual(interaction.nextDeadline, 4)
    }

    func testClickingExpandedCardDoesNotCloseIt() {
        var interaction = opened()
        interaction.update(now: 2, inTrigger: false, inCard: true, mouseDown: true)
        XCTAssertEqual(interaction.phase, .expanded)
        XCTAssertTrue(interaction.isVisible)
    }

    func testRepeatedOpenCloseCyclesStartFreshDeadlines() {
        var interaction = NotchInteraction()
        for cycle in 0..<20 {
            let start = Double(cycle * 10)
            interaction.update(now: start, inTrigger: true, inCard: false)
            XCTAssertEqual(interaction.nextDeadline, start + 1)
            interaction.update(now: start + 1, inTrigger: true, inCard: false)
            XCTAssertTrue(interaction.isVisible)
            interaction.update(now: start + 2, inTrigger: false, inCard: false)
            interaction.update(now: start + 3, inTrigger: false, inCard: false)
            XCTAssertEqual(interaction.phase, .closed)
        }
    }

    private func opened() -> NotchInteraction {
        var interaction = NotchInteraction()
        interaction.update(now: 0, inTrigger: true, inCard: false)
        interaction.update(now: 1, inTrigger: true, inCard: false)
        return interaction
    }
}
