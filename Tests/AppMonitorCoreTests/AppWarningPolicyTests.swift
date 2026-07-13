import Foundation
import XCTest
@testable import AppMonitorCore

final class AppWarningPolicyTests: XCTestCase {
    private let policy = AppWarningPolicy()

    func testProtectedSystemWarningsAreExcluded() {
        let warning = makeWarning(
            id: "system",
            appPath: "/System/Applications/Mail.app",
            severity: .critical,
            source: "Code Signing"
        )

        XCTAssertTrue(policy.actionableWarnings(from: [warning]).isEmpty)
    }

    func testSpeculativeUsageAndUpdateSignalsAreExcluded() {
        let usage = makeWarning(id: "usage", severity: .medium, source: "Usage Analytics")
        let stale = makeWarning(id: "stale", severity: .medium, source: "Update Signal")

        XCTAssertTrue(policy.actionableWarnings(from: [usage, stale]).isEmpty)
    }

    func testDuplicateNormalizedPathsCollapseToHighestConfidenceFinding() {
        let path = "/Applications/Example.app/Contents/../Contents/Resources/cache"
        let lowerConfidence = makeWarning(
            id: "cleanup",
            severity: .high,
            source: "Cleanup Analyzer",
            affectedPath: path
        )
        let higherConfidence = makeWarning(
            id: "storage",
            severity: .high,
            source: "Storage Scan",
            affectedPath: "/Applications/Example.app/Contents/Resources/cache"
        )

        let warnings = policy.actionableWarnings(from: [lowerConfidence, higherConfidence])

        XCTAssertEqual(warnings.map(\.id), ["storage"])
    }

    func testActionableWarningsAreRankedBySeverityThenConfidence() {
        let medium = makeWarning(id: "medium", severity: .medium, source: "Storage Scan", affectedPath: "/tmp/medium")
        let high = makeWarning(id: "high", severity: .high, source: "Cleanup Analyzer", affectedPath: "/tmp/high")
        let critical = makeWarning(id: "critical", severity: .critical, source: "Filesystem", affectedPath: "/tmp/critical")

        XCTAssertEqual(policy.actionableWarnings(from: [medium, high, critical]).map(\.id), ["critical", "high", "medium"])
    }

    private func makeWarning(
        id: String,
        appPath: String = "/Applications/Example.app",
        severity: AppWarningSeverity,
        source: String,
        affectedPath: String? = nil
    ) -> AppWarningItem {
        AppWarningItem(
            id: id,
            appID: "example",
            appName: "Example",
            appPath: appPath,
            bundleIdentifier: "com.example.app",
            title: "Review Needed",
            detail: "A verified condition needs review.",
            recommendation: "Review the affected item.",
            severity: severity,
            category: .storage,
            source: source,
            detectedAt: Date(timeIntervalSince1970: 1),
            affectedItems: affectedPath.map {
                [AppWarningAffectedItem(title: "Item", subtitle: "Storage", path: $0)]
            } ?? []
        )
    }
}
