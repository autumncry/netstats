import AppKit
import XCTest
@testable import NetStatsCore

@MainActor final class HubClipboardCaptureTests: XCTestCase {
    func testResumeDoesNotCaptureContentCopiedWhilePaused() async throws {
        let fixture = try Fixture()
        defer { fixture.cleanUp() }
        let store = ClipboardStore(defaults: fixture.defaults, directory: fixture.directory, pasteboard: fixture.pasteboard)
        store.setEnabled(true)
        store.paused = true
        fixture.writeText("excluded paused content")
        await store.pollOnce()
        store.paused = false
        await store.pollOnce()
        await store.reload()
        XCTAssertTrue(store.entries.isEmpty, "Resuming must not save the paused clipboard backlog")
        fixture.writeText("new explicit copy")
        await store.pollOnce()
        XCTAssertEqual(store.entries.map(\.text), ["new explicit copy"])
        store.stop()
    }

    func testPausedOrDisabledCollectionDiscardsInFlightImageConversion() async throws {
        for pause in [true, false] {
            let fixture = try Fixture()
            defer { fixture.cleanUp() }
            let converter = SuspendedImageConverter()
            let store = ClipboardStore(defaults: fixture.defaults, directory: fixture.directory, pasteboard: fixture.pasteboard,
                                       imageConverter: { await converter.convert($0) })
            store.setEnabled(true)
            fixture.writeTIFF()
            let operation = Task { await store.pollOnce() }
            await converter.waitForStart()
            if pause { store.paused = true } else { store.setEnabled(false) }
            await converter.resume()
            await operation.value
            await store.reload()
            XCTAssertTrue(store.entries.isEmpty, "A prior collection session must not persist a converted image")
            store.stop()
        }
    }

    func testClearInvalidatesInFlightImageAndDoesNotRecaptureIt() async throws {
        let fixture = try Fixture()
        defer { fixture.cleanUp() }
        let converter = SuspendedImageConverter()
        let store = ClipboardStore(defaults: fixture.defaults, directory: fixture.directory, pasteboard: fixture.pasteboard,
                                   imageConverter: { await converter.convert($0) })
        store.setEnabled(true)
        fixture.writeTIFF()
        let operation = Task { await store.pollOnce() }
        await converter.waitForStart()
        await store.clearHistory().value
        await converter.resume()
        await operation.value
        await store.pollOnce()
        await store.reload()
        XCTAssertTrue(store.entries.isEmpty, "An image captured before Clear must not reappear afterwards")
        store.stop()
    }

    private struct Fixture {
        let directory: URL
        let defaults: UserDefaults
        let suite: String
        let pasteboard: NSPasteboard

        init() throws {
            directory = FileManager.default.temporaryDirectory.appendingPathComponent("NetStatsCaptureTests-\(UUID().uuidString)")
            suite = "NetStatsCaptureTests-\(UUID().uuidString)"
            defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
            pasteboard = NSPasteboard.withUniqueName()
        }
        func writeText(_ text: String) {
            pasteboard.clearContents()
            pasteboard.setString(text, forType: .string)
            pasteboard.setString("com.example.synthetic", forType: NSPasteboard.PasteboardType("org.nspasteboard.source"))
        }
        func writeTIFF() {
            pasteboard.clearContents()
            pasteboard.setData(Data([1, 2]), forType: .tiff)
            pasteboard.setString("com.example.synthetic", forType: NSPasteboard.PasteboardType("org.nspasteboard.source"))
        }
        func cleanUp() {
            pasteboard.releaseGlobally()
            defaults.removePersistentDomain(forName: suite)
            try? FileManager.default.removeItem(at: directory)
        }
    }
}

private actor SuspendedImageConverter {
    private var started = false
    private var continuation: CheckedContinuation<Data?, Never>?
    func convert(_ input: Data) async -> Data? {
        started = true
        return await withCheckedContinuation { continuation = $0 }
    }
    func waitForStart() async {
        while !started { await Task.yield() }
    }
    func resume() { continuation?.resume(returning: Data([3, 4])); continuation = nil }
}
