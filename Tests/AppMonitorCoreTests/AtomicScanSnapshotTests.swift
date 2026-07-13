import XCTest
@testable import AppMonitorCore

final class AtomicScanSnapshotTests: XCTestCase {
    func testScanPhaseCoversStartProgressCompletionAndFailure() {
        let start = ScanSnapshotPhase.refreshing(completed: 0, total: 4)
        let progress = ScanSnapshotPhase.refreshing(completed: 2, total: 4)
        let completion = ScanSnapshotPhase.completed(Date(timeIntervalSince1970: 100))
        let failure = ScanSnapshotPhase.failed("disk read failed")

        XCTAssertTrue(start.isRefreshing)
        XCTAssertFalse(start.allowsSnapshotActions)
        XCTAssertEqual(progress, .refreshing(completed: 2, total: 4))
        XCTAssertTrue(completion.allowsSnapshotActions)
        XCTAssertTrue(failure.allowsSnapshotActions)
    }

    func testCompletedSnapshotPublishesAllAppsTogether() throws {
        let store = try makeStore()
        let first = item(id: "first", appID: "app.one", bytes: 10)
        let second = item(id: "second", appID: "app.two", bytes: 20)

        try store.publishCompletedScanSnapshot(snapshot(items: ["app.one": [first], "app.two": [second]]))

        XCTAssertEqual(try store.fetchStorageItems(appID: "app.one"), [first])
        XCTAssertEqual(try store.fetchStorageItems(appID: "app.two"), [second])
    }

    func testFailedSnapshotRollsBackEveryApp() throws {
        let store = try makeStore()
        let original = item(id: "original", appID: "app.one", bytes: 10)
        try store.replaceStorageItems(for: "app.one", items: [original])

        let duplicateOne = item(id: "duplicate", appID: "app.one", bytes: 100)
        let duplicateTwo = item(id: "duplicate", appID: "app.two", bytes: 200)
        XCTAssertThrowsError(
            try store.publishCompletedScanSnapshot(snapshot(items: [
                "app.one": [duplicateOne],
                "app.two": [duplicateTwo]
            ]))
        )

        XCTAssertEqual(try store.fetchStorageItems(appID: "app.one"), [original])
        XCTAssertTrue(try store.fetchStorageItems(appID: "app.two").isEmpty)
    }

    private func makeStore() throws -> AppDataStore {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        return try AppDataStore(databaseURL: directory.appendingPathComponent("test.sqlite"))
    }

    private func item(id: String, appID: String, bytes: Int64) -> StorageScanItem {
        StorageScanItem(
            id: id,
            appID: appID,
            category: .caches,
            path: "/tmp/\(appID)/\(id)",
            sizeBytes: bytes,
            scannedAt: Date(timeIntervalSince1970: 100)
        )
    }

    private func snapshot(items: [String: [StorageScanItem]]) -> CompletedAppScanSnapshot {
        CompletedAppScanSnapshot(
            storageItemsByAppID: items,
            healthFindingsByAppID: Dictionary(uniqueKeysWithValues: items.keys.map { ($0, []) }),
            cleanupSuggestionsByAppID: Dictionary(uniqueKeysWithValues: items.keys.map { ($0, []) }),
            largeFiles: []
        )
    }
}
