import XCTest
@testable import AppMonitorCore

final class CleanupEvidencePolicyTests: XCTestCase {
    private func app(path: String = "/Applications/Example.app", bundleID: String? = "com.example.app") -> MonitoredApp {
        MonitoredApp(id: "app", name: "Example", bundleIdentifier: bundleID, version: "1", path: path, isUserFacing: true)
    }

    func testConfidenceAndExclusionsStayConsistentWithCleanupRules() {
        XCTAssertEqual(CleanupEvidencePolicy.confidence(for: .caches), .high)
        XCTAssertEqual(CleanupEvidencePolicy.confidence(for: .applicationSupport), .reviewRequired)
        XCTAssertFalse(CleanupEvidencePolicy.isProtectedFromCleanupSuggestion(.caches))
        XCTAssertTrue(CleanupEvidencePolicy.isProtectedFromCleanupSuggestion(.bundle))
        XCTAssertTrue(CleanupEvidencePolicy.isProtectedFromCleanupSuggestion(.preferences))
        XCTAssertNotNil(CleanupEvidencePolicy.exclusionReason(for: .containers))
        XCTAssertNil(CleanupEvidencePolicy.exclusionReason(for: .logs))
    }

    func testSystemApplicationsNeverProduceCleanupSuggestions() {
        let systemApp = app(path: "/System/Applications/Mail.app", bundleID: "com.apple.mail")
        let row = AppUsageRow(app: systemApp, usageSeconds: 0, lastUsed: nil, bundleSizeBytes: 0, relatedSizeBytes: 2_000_000, warningCount: 0, scannedAt: Date())
        let cache = StorageScanItem(appID: systemApp.id, category: .caches, path: "/Users/test/Library/Caches/com.apple.mail", sizeBytes: 2_000_000)

        XCTAssertTrue(CleanupEvidencePolicy.isProtectedFromCleanupSuggestion(category: cache.category, path: cache.path, app: systemApp))
        XCTAssertTrue(CleanupAnalyzer().suggestions(for: row, items: [cache]).isEmpty)
    }

    func testICloudAssociatedDataNeverProducesCleanupSuggestions() {
        let userApp = app()
        let row = AppUsageRow(app: userApp, usageSeconds: 0, lastUsed: nil, bundleSizeBytes: 0, relatedSizeBytes: 2_000_000, warningCount: 0, scannedAt: Date())
        let cloudData = StorageScanItem(appID: userApp.id, category: .applicationSupport, path: "/Users/test/Library/Mobile Documents/com~example~app/Documents", sizeBytes: 2_000_000)

        XCTAssertTrue(CleanupEvidencePolicy.isICloudAssociated(path: cloudData.path))
        XCTAssertTrue(CleanupAnalyzer().suggestions(for: row, items: [cloudData]).isEmpty)
    }

    func testDeveloperCachesRequireReviewInsteadOfHighConfidence() {
        let userApp = app(path: "/Applications/Xcode.app", bundleID: "com.example.xcode")
        let path = "/Users/test/Library/Developer/Xcode/DerivedData/Example"

        XCTAssertTrue(CleanupEvidencePolicy.isDeveloperCache(path: path))
        XCTAssertEqual(CleanupEvidencePolicy.confidence(for: .caches, path: path, app: userApp), .reviewRequired)
        XCTAssertFalse(CleanupEvidencePolicy.isProtectedFromCleanupSuggestion(category: .caches, path: path, app: userApp))
        XCTAssertTrue(CleanupEvidencePolicy.appliedExclusions(category: .caches, path: path, app: userApp).contains("requires review"))
    }
}
