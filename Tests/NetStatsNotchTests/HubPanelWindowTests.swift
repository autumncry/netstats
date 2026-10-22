import AppKit
import XCTest
@testable import NetStatsCore

final class HubPanelWindowTests: XCTestCase {
    func testPassivePanelCannotTakeKeyboardOrMainWindowStatus() async {
        await MainActor.run {
            _ = NSApplication.shared
            let panel = HubPanel()
            XCTAssertFalse(panel.canBecomeKey)
            XCTAssertFalse(panel.canBecomeMain)
            panel.allowsKeyboardFocus = true
            XCTAssertTrue(panel.canBecomeKey)
            XCTAssertFalse(panel.canBecomeMain)
            panel.endInteraction()
            XCTAssertFalse(panel.canBecomeKey)
        }
    }

    func testOwnedWindowIsRecognizedThroughItsParentChain() async {
        await MainActor.run {
            _ = NSApplication.shared
            let panel = HubPanel()
            let child = NSPanel(contentRect: .zero, styleMask: .borderless, backing: .buffered, defer: false)
            let unrelated = NSPanel(contentRect: .zero, styleMask: .borderless, backing: .buffered, defer: false)
            panel.addChildWindow(child, ordered: .above)
            XCTAssertTrue(panel.owns(panel))
            XCTAssertTrue(panel.owns(child))
            XCTAssertFalse(panel.owns(unrelated))
            XCTAssertFalse(panel.owns(nil))
            panel.removeChildWindow(child)
        }
    }

    func testDropValidationAcceptsExistingFilesAndRejectsMissingReferences() async throws {
        try await MainActor.run {
            let folder = FileManager.default.temporaryDirectory.appendingPathComponent("netstats-drop-\(UUID().uuidString)")
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(at: folder) }
            let valid = folder.appendingPathComponent("sample.txt")
            try Data("fixture".utf8).write(to: valid)
            let missing = folder.appendingPathComponent("missing.txt")
            let board = NSPasteboard(name: .init("netstats-test-\(UUID().uuidString)"))
            defer { board.releaseGlobally() }
            XCTAssertTrue(board.writeObjects([valid as NSURL, missing as NSURL]))
            XCTAssertEqual(NotchDropDestinationView.fileURLs(from: board), [valid])
        }
    }
}
