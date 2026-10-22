import AppKit
import XCTest
@testable import NetStatsCore

@MainActor final class HubShelfTests: XCTestCase {
    func testShelfPersistsReferencesAndRemovalDoesNotDeleteOriginal() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("NetStatsShelfTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let original = directory.appendingPathComponent("original.txt")
        try Data("keep me".utf8).write(to: original)
        let suite = "NetStatsShelfTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = ShelfStore(defaults: defaults)
        store.add(urls: [original, original])
        XCTAssertEqual(store.items.count, 1)
        let reopened = ShelfStore(defaults: defaults)
        XCTAssertEqual(reopened.items.first?.url?.standardizedFileURL.path, original.standardizedFileURL.path)
        reopened.remove(try XCTUnwrap(reopened.items.first).id)
        XCTAssertTrue(reopened.items.isEmpty)
        XCTAssertEqual(try String(contentsOf: original, encoding: .utf8), "keep me")
    }

    func testShelfMarksMissingReferenceUnavailable() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("NetStatsShelfTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("gone.txt")
        try Data().write(to: file)
        let suite = "NetStatsShelfTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = ShelfStore(defaults: defaults)
        store.add(urls: [file])
        try FileManager.default.removeItem(at: file)
        store.refreshAvailability()
        XCTAssertEqual(store.items.count, 1)
        XCTAssertFalse(try XCTUnwrap(store.items.first).isAvailable)
    }
}
