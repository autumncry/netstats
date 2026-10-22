import Foundation
import XCTest
@testable import NetStatsCore

final class HubClipboardPersistenceTests: XCTestCase {
    func testUnlimitedHistoryPersistsBeyondOnePageAndSearchEscapesWildcards() async throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = try ClipboardRepository(directory: directory)
        for index in 0..<65 {
            _ = try await repository.insertText("entry \(index)", source: "test", at: Date(timeIntervalSince1970: 1_000 + Double(index)))
        }
        _ = try await repository.insertText("literal 100%_match", source: nil, at: Date(timeIntervalSince1970: 1_100))
        try await repository.purge(policy: ClipboardRetentionPolicy(days: 30, textLimit: 0, imageLimit: 0), now: Date(timeIntervalSince1970: 1_200))
        let first = try await repository.query(search: "", after: nil, limit: 30)
        XCTAssertEqual(first.count, 30)
        let second = try await repository.query(search: "", after: first.last?.id, limit: 30)
        XCTAssertEqual(second.count, 30)
        XCTAssertTrue(Set(first.map(\.id)).isDisjoint(with: second.map(\.id)))
        let third = try await repository.query(search: "", after: second.last?.id, limit: 30)
        XCTAssertEqual(third.count, 6)
        let matches = try await repository.query(search: "100%_", after: nil, limit: 30)
        XCTAssertEqual(matches.map(\.text), ["literal 100%_match"])
        let reopened = try ClipboardRepository(directory: directory)
        let persisted = try await reopened.query(search: "entry 64", after: nil, limit: 10)
        XCTAssertEqual(persisted.first?.text, "entry 64")
    }

    func testRetentionAndSeparateCapsRemoveExpiredImagesFromDisk() async throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = try ClipboardRepository(directory: directory)
        let now = Date(timeIntervalSince1970: 1_000_000)
        _ = try await repository.insertText("expired", source: nil, at: now.addingTimeInterval(-90_000))
        _ = try await repository.insertText("older", source: nil, at: now.addingTimeInterval(-20))
        _ = try await repository.insertText("newer", source: nil, at: now.addingTimeInterval(-10))
        let oldImage = try await repository.insertImage(Data([1, 2, 3]), source: nil, at: now.addingTimeInterval(-15))
        _ = try await repository.insertImage(Data([4, 5, 6]), source: nil, at: now)
        try await repository.purge(policy: ClipboardRetentionPolicy(days: 1, textLimit: 1, imageLimit: 1), now: now)
        let entries = try await repository.query(search: "", after: nil, limit: 100)
        XCTAssertEqual(entries.count, 2)
        XCTAssertEqual(entries.compactMap(\.text), ["newer"])
        XCTAssertFalse(FileManager.default.fileExists(atPath: directory.appendingPathComponent("images").appendingPathComponent(try XCTUnwrap(oldImage.imageFilename)).path))
        let removedSearch = try await repository.query(search: "older", after: nil, limit: 30)
        XCTAssertTrue(removedSearch.isEmpty)
        try await repository.clear()
        let cleared = try await repository.query(search: "newer", after: nil, limit: 30)
        XCTAssertTrue(cleared.isEmpty)
        XCTAssertTrue(try FileManager.default.contentsOfDirectory(at: directory.appendingPathComponent("images"), includingPropertiesForKeys: nil).isEmpty)
    }

    func testClipboardPrivacyPolicyRejectsSensitiveSourcesAndRequiresExplicitRead() {
        XCTAssertFalse(ClipboardCapturePolicy.mayCollect(enabled: false, paused: false, access: .allowed))
        XCTAssertFalse(ClipboardCapturePolicy.mayCollect(enabled: true, paused: false, access: .requiresUserAction))
        XCTAssertFalse(ClipboardCapturePolicy.mayCollect(enabled: true, paused: true, access: .allowed))
        XCTAssertTrue(ClipboardCapturePolicy.mayCollect(enabled: true, paused: false, access: .legacy))
        XCTAssertTrue(ClipboardCapturePolicy.shouldIgnore(types: ["org.nspasteboard.ConcealedType"], source: nil, excludedApps: []))
        XCTAssertTrue(ClipboardCapturePolicy.shouldIgnore(types: ["org.nspasteboard.TransientType"], source: nil, excludedApps: []))
        XCTAssertTrue(ClipboardCapturePolicy.shouldIgnore(types: ["public.utf8-plain-text"], source: "com.example.Secret", excludedApps: ["com.example.Secret"]))
        XCTAssertFalse(ClipboardCapturePolicy.shouldIgnore(types: ["public.utf8-plain-text"], source: "com.example.Editor", excludedApps: ["com.example.Secret"]))
    }

    func testExpiredImageDeletionRetriesAfterTemporaryFilesystemFailure() async throws {
        let directory = temporaryDirectory()
        let images = directory.appendingPathComponent("images")
        defer {
            try? FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: images.path)
            try? FileManager.default.removeItem(at: directory)
        }
        let repository = try ClipboardRepository(directory: directory)
        let now = Date()
        let entry = try await repository.insertImage(Data([1]), source: nil, at: now.addingTimeInterval(-90_000))
        let image = images.appendingPathComponent(try XCTUnwrap(entry.imageFilename))
        try FileManager.default.setAttributes([.posixPermissions: 0o500], ofItemAtPath: images.path)
        let firstCleanup = try await repository.purge(policy: ClipboardRetentionPolicy(days: 1, textLimit: 0, imageLimit: 0), now: now)
        XCTAssertEqual(firstCleanup.failedImages, 1)
        XCTAssertTrue(FileManager.default.fileExists(atPath: image.path))
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: images.path)
        try await repository.purge(policy: ClipboardRetentionPolicy(days: 1, textLimit: 0, imageLimit: 0), now: now)
        XCTAssertFalse(FileManager.default.fileExists(atPath: image.path))
    }

    func testFailedImageUnlinkDoesNotBlockLaterExpiryOrCountCaps() async throws {
        let directory = temporaryDirectory()
        let images = directory.appendingPathComponent("images")
        defer {
            try? FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: images.path)
            try? FileManager.default.removeItem(at: directory)
        }
        let repository = try ClipboardRepository(directory: directory)
        let now = Date()
        _ = try await repository.insertImage(Data([1]), source: nil, at: now.addingTimeInterval(-90_000))
        try FileManager.default.setAttributes([.posixPermissions: 0o500], ofItemAtPath: images.path)
        let initialCleanup = try await repository.purge(policy: ClipboardRetentionPolicy(days: 1, textLimit: 1, imageLimit: 0), now: now)
        XCTAssertEqual(initialCleanup.failedImages, 1)
        _ = try await repository.insertText("expired", source: nil, at: now.addingTimeInterval(-90_000))
        _ = try await repository.insertText("over cap", source: nil, at: now.addingTimeInterval(-2))
        _ = try await repository.insertText("retained", source: nil, at: now)
        let laterCleanup = try await repository.purge(policy: ClipboardRetentionPolicy(days: 1, textLimit: 1, imageLimit: 0), now: now)
        XCTAssertEqual(laterCleanup.failedImages, 1)
        let rows = try await repository.query(search: "", after: nil, limit: 30)
        XCTAssertEqual(rows.map(\.text), ["retained"], "A queued unlink failure must not block unrelated metadata retention")
    }

    private func temporaryDirectory() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("NetStatsClipboardTests-\(UUID().uuidString)", isDirectory: true)
    }
}
