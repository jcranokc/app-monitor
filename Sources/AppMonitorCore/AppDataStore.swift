import Foundation

public final class AppDataStore {
    private let queue = DispatchQueue(label: "com.jacob.appmonitor.datastore")
    private let database: SQLiteDatabase
    public let databaseURL: URL

    public convenience init() throws {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("App Monitor", isDirectory: true)
        try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        try self.init(databaseURL: base.appendingPathComponent("AppMonitor.sqlite"))
    }

    public init(databaseURL: URL) throws {
        let parent = databaseURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
        self.databaseURL = databaseURL
        self.database = try SQLiteDatabase(url: databaseURL)
        try migrate()
    }

    private func migrate() throws {
        try queue.sync {
            try database.execute("""
            CREATE TABLE IF NOT EXISTS apps (
                id TEXT PRIMARY KEY,
                bundle_id TEXT,
                name TEXT NOT NULL,
                version TEXT,
                path TEXT NOT NULL UNIQUE,
                is_user_facing INTEGER NOT NULL,
                installed_at REAL,
                bundle_created_at REAL,
                last_seen REAL NOT NULL
            )
            """)
            try? database.execute("ALTER TABLE apps ADD COLUMN installed_at REAL")
            try? database.execute("ALTER TABLE apps ADD COLUMN bundle_created_at REAL")

            try database.execute("""
            CREATE TABLE IF NOT EXISTS usage_segments (
                id TEXT PRIMARY KEY,
                app_id TEXT NOT NULL,
                bundle_id TEXT,
                app_name TEXT NOT NULL,
                app_path TEXT NOT NULL,
                started_at REAL NOT NULL,
                ended_at REAL NOT NULL,
                duration_seconds REAL NOT NULL
            )
            """)

            try database.execute("""
            CREATE INDEX IF NOT EXISTS idx_usage_segments_period
            ON usage_segments(started_at, ended_at)
            """)

            try database.execute("""
            CREATE INDEX IF NOT EXISTS idx_usage_segments_app_period
            ON usage_segments(app_id, started_at, ended_at)
            """)

            try database.execute("""
            CREATE INDEX IF NOT EXISTS idx_usage_segments_started_at
            ON usage_segments(started_at)
            """)

            try database.execute("""
            CREATE INDEX IF NOT EXISTS idx_usage_segments_ended_at
            ON usage_segments(ended_at)
            """)

            try database.execute("""
            CREATE TABLE IF NOT EXISTS storage_items (
                id TEXT PRIMARY KEY,
                app_id TEXT NOT NULL,
                category TEXT NOT NULL,
                path TEXT NOT NULL,
                size_bytes INTEGER NOT NULL,
                warning TEXT,
                scanned_at REAL NOT NULL
            )
            """)

            try database.execute("""
            CREATE INDEX IF NOT EXISTS idx_storage_items_app
            ON storage_items(app_id)
            """)

            try database.execute("""
            CREATE TABLE IF NOT EXISTS imported_usage_history (
                app_id TEXT PRIMARY KEY,
                last_used REAL,
                use_count INTEGER,
                imported_at REAL NOT NULL
            )
            """)

            try database.execute("""
            CREATE TABLE IF NOT EXISTS imported_usage_days (
                app_id TEXT NOT NULL,
                day_start REAL NOT NULL,
                PRIMARY KEY (app_id, day_start)
            )
            """)

            try database.execute("""
            CREATE INDEX IF NOT EXISTS idx_imported_usage_days_period
            ON imported_usage_days(day_start)
            """)

            try database.execute("""
            CREATE TABLE IF NOT EXISTS settings (
                key TEXT PRIMARY KEY,
                value TEXT NOT NULL
            )
            """)

            try database.execute("""
            CREATE TABLE IF NOT EXISTS health_findings (
                id TEXT PRIMARY KEY,
                app_id TEXT NOT NULL,
                severity TEXT NOT NULL,
                title TEXT NOT NULL,
                detail TEXT NOT NULL,
                source TEXT NOT NULL,
                checked_at REAL NOT NULL
            )
            """)

            try database.execute("""
            CREATE INDEX IF NOT EXISTS idx_health_findings_app
            ON health_findings(app_id)
            """)

            try database.execute("""
            CREATE TABLE IF NOT EXISTS cleanup_suggestions (
                id TEXT PRIMARY KEY,
                app_id TEXT NOT NULL,
                title TEXT NOT NULL,
                path TEXT NOT NULL,
                category TEXT NOT NULL,
                size_bytes INTEGER NOT NULL,
                severity TEXT NOT NULL,
                rationale TEXT NOT NULL,
                risk_notes TEXT NOT NULL,
                state TEXT NOT NULL,
                quarantine_path TEXT,
                created_at REAL NOT NULL,
                updated_at REAL NOT NULL
            )
            """)

            try database.execute("""
            CREATE INDEX IF NOT EXISTS idx_cleanup_suggestions_app
            ON cleanup_suggestions(app_id)
            """)

            try database.execute("""
            CREATE TABLE IF NOT EXISTS large_files (
                id TEXT PRIMARY KEY,
                app_id TEXT NOT NULL,
                path TEXT NOT NULL,
                category TEXT NOT NULL,
                size_bytes INTEGER NOT NULL,
                risk_score INTEGER NOT NULL,
                risk_reason TEXT NOT NULL,
                modified_at REAL,
                state TEXT NOT NULL,
                scanned_at REAL NOT NULL
            )
            """)
            try? database.execute("ALTER TABLE large_files ADD COLUMN modified_at REAL")

            try database.execute("""
            CREATE INDEX IF NOT EXISTS idx_large_files_app
            ON large_files(app_id)
            """)

            try database.execute("""
            CREATE TABLE IF NOT EXISTS app_tags (
                app_id TEXT NOT NULL,
                tag TEXT NOT NULL,
                PRIMARY KEY (app_id, tag)
            )
            """)

            try database.execute("""
            CREATE TABLE IF NOT EXISTS ignored_apps (
                app_id TEXT PRIMARY KEY,
                ignored_at REAL NOT NULL
            )
            """)

            try database.execute("""
            CREATE TABLE IF NOT EXISTS action_history (
                id TEXT PRIMARY KEY,
                title TEXT NOT NULL,
                detail TEXT NOT NULL,
                created_at REAL NOT NULL
            )
            """)

            try database.execute("""
            CREATE TABLE IF NOT EXISTS warning_triage (
                warning_id TEXT PRIMARY KEY,
                disposition TEXT NOT NULL,
                snapshot_json TEXT NOT NULL,
                first_seen_at REAL NOT NULL,
                last_seen_at REAL NOT NULL,
                updated_at REAL NOT NULL
            )
            """)

            try database.execute("""
            CREATE TABLE IF NOT EXISTS warning_triage_history (
                id TEXT PRIMARY KEY,
                warning_id TEXT NOT NULL,
                action TEXT NOT NULL,
                detail TEXT NOT NULL,
                created_at REAL NOT NULL
            )
            """)

            try database.execute("""
            CREATE INDEX IF NOT EXISTS idx_warning_triage_history_warning
            ON warning_triage_history(warning_id, created_at)
            """)

            try database.execute("""
            CREATE TABLE IF NOT EXISTS uninstall_runs (
                id TEXT PRIMARY KEY,
                app_id TEXT NOT NULL,
                app_name TEXT NOT NULL,
                app_path TEXT NOT NULL,
                bundle_id TEXT,
                status TEXT NOT NULL,
                started_at REAL NOT NULL,
                completed_at REAL NOT NULL,
                selected_item_count INTEGER NOT NULL,
                trashed_item_count INTEGER NOT NULL,
                failed_item_count INTEGER NOT NULL,
                skipped_item_count INTEGER NOT NULL,
                selected_bytes INTEGER NOT NULL,
                message TEXT
            )
            """)

            try database.execute("""
            CREATE INDEX IF NOT EXISTS idx_uninstall_runs_app
            ON uninstall_runs(app_id, completed_at)
            """)

            try database.execute("""
            CREATE TABLE IF NOT EXISTS uninstall_item_results (
                id TEXT PRIMARY KEY,
                run_id TEXT NOT NULL,
                item_id TEXT NOT NULL,
                app_id TEXT NOT NULL,
                path TEXT NOT NULL,
                category TEXT NOT NULL,
                role TEXT NOT NULL,
                size_bytes INTEGER NOT NULL,
                risk TEXT NOT NULL,
                status TEXT NOT NULL,
                message TEXT,
                completed_at REAL NOT NULL
            )
            """)

            try database.execute("""
            CREATE INDEX IF NOT EXISTS idx_uninstall_item_results_run
            ON uninstall_item_results(run_id)
            """)

            try database.execute("""
            CREATE TABLE IF NOT EXISTS app_updates (
                id TEXT PRIMARY KEY,
                app_id TEXT,
                app_name TEXT NOT NULL,
                bundle_id TEXT,
                app_path TEXT,
                source TEXT NOT NULL,
                source_identifier TEXT NOT NULL,
                current_version TEXT,
                available_version TEXT,
                status TEXT NOT NULL,
                checked_at REAL NOT NULL,
                install_action_title TEXT NOT NULL,
                install_action_url TEXT,
                requires_admin INTEGER NOT NULL,
                requires_restart INTEGER NOT NULL,
                can_install INTEGER NOT NULL,
                is_auto_eligible INTEGER NOT NULL,
                release_notes_title TEXT,
                release_notes_summary TEXT,
                release_notes_url TEXT,
                message TEXT
            )
            """)
            try? database.execute("ALTER TABLE app_updates ADD COLUMN release_notes_title TEXT")
            try? database.execute("ALTER TABLE app_updates ADD COLUMN release_notes_summary TEXT")
            try? database.execute("ALTER TABLE app_updates ADD COLUMN release_notes_url TEXT")

            try database.execute("""
            CREATE INDEX IF NOT EXISTS idx_app_updates_app
            ON app_updates(app_id, checked_at)
            """)

            try database.execute("""
            CREATE TABLE IF NOT EXISTS app_changelogs (
                id TEXT PRIMARY KEY,
                app_id TEXT,
                app_name TEXT NOT NULL,
                bundle_id TEXT,
                app_path TEXT,
                source TEXT NOT NULL,
                source_identifier TEXT NOT NULL,
                from_version TEXT,
                to_version TEXT,
                title TEXT NOT NULL,
                summary TEXT NOT NULL,
                release_notes_url TEXT,
                update_run_id TEXT,
                update_result_id TEXT,
                captured_at REAL NOT NULL
            )
            """)

            try database.execute("""
            CREATE INDEX IF NOT EXISTS idx_app_changelogs_app
            ON app_changelogs(app_id, captured_at)
            """)

            try database.execute("""
            CREATE TABLE IF NOT EXISTS update_runs (
                id TEXT PRIMARY KEY,
                mode TEXT NOT NULL,
                status TEXT NOT NULL,
                started_at REAL NOT NULL,
                completed_at REAL NOT NULL,
                selected_item_count INTEGER NOT NULL,
                updated_item_count INTEGER NOT NULL,
                failed_item_count INTEGER NOT NULL,
                skipped_item_count INTEGER NOT NULL,
                message TEXT
            )
            """)

            try database.execute("""
            CREATE TABLE IF NOT EXISTS update_item_results (
                id TEXT PRIMARY KEY,
                run_id TEXT NOT NULL,
                update_id TEXT NOT NULL,
                app_id TEXT,
                app_name TEXT NOT NULL,
                source TEXT NOT NULL,
                source_identifier TEXT NOT NULL,
                status TEXT NOT NULL,
                message TEXT,
                completed_at REAL NOT NULL
            )
            """)

            try database.execute("""
            CREATE INDEX IF NOT EXISTS idx_update_item_results_run
            ON update_item_results(run_id)
            """)
        }
    }

    public func upsertApps(_ apps: [MonitoredApp]) throws {
        try queue.sync {
            try database.execute("BEGIN IMMEDIATE")
            do {
                for app in apps {
                    try database.execute(
                        """
                        INSERT INTO apps (id, bundle_id, name, version, path, is_user_facing, installed_at, bundle_created_at, last_seen)
                        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
                        ON CONFLICT(path) DO UPDATE SET
                            id = excluded.id,
                            bundle_id = excluded.bundle_id,
                            name = excluded.name,
                            version = excluded.version,
                            is_user_facing = excluded.is_user_facing,
                            installed_at = excluded.installed_at,
                            bundle_created_at = excluded.bundle_created_at,
                            last_seen = excluded.last_seen
                        """,
                        [
                            .text(app.id),
                            app.bundleIdentifier.map(SQLiteValue.text) ?? .null,
                            .text(app.name),
                            app.version.map(SQLiteValue.text) ?? .null,
                            .text(app.path),
                            .int64(app.isUserFacing ? 1 : 0),
                            app.installedAt.map { SQLiteValue.double($0.timeIntervalSince1970) } ?? .null,
                            app.bundleCreatedAt.map { SQLiteValue.double($0.timeIntervalSince1970) } ?? .null,
                            .double(app.lastSeen.timeIntervalSince1970)
                        ]
                    )
                }
                try database.execute("COMMIT")
            } catch {
                try? database.execute("ROLLBACK")
                throw error
            }
        }
    }

    public func fetchApps(includeAll: Bool) throws -> [MonitoredApp] {
        try queue.sync {
            let sql = includeAll
                ? "SELECT * FROM apps ORDER BY lower(name), path"
                : "SELECT * FROM apps WHERE is_user_facing = 1 ORDER BY lower(name), path"

            let apps = try database.query(sql).compactMap(Self.app(from:))
            return AppInventoryScanner.reconcileInventory(apps)
        }
    }

    public func insertUsageSegment(_ segment: UsageSegment) throws {
        guard segment.durationSeconds >= 1 else { return }
        try queue.sync {
            try database.execute(
                """
                INSERT OR REPLACE INTO usage_segments
                (id, app_id, bundle_id, app_name, app_path, started_at, ended_at, duration_seconds)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                """,
                [
                    .text(segment.id),
                    .text(segment.appID),
                    segment.bundleIdentifier.map(SQLiteValue.text) ?? .null,
                    .text(segment.appName),
                    .text(segment.appPath),
                    .double(segment.startedAt.timeIntervalSince1970),
                    .double(segment.endedAt.timeIntervalSince1970),
                    .double(segment.durationSeconds)
                ]
            )
        }
    }

    public func fetchAllUsageSegments() throws -> [UsageSegment] {
        try queue.sync {
            try database.query("SELECT * FROM usage_segments ORDER BY started_at")
                .compactMap(Self.segment(from:))
        }
    }

    public func monitoringHistorySummary() throws -> MonitoringHistorySummary {
        try queue.sync {
            let usage = try database.query(
                "SELECT COUNT(*) AS event_count, MIN(started_at) AS earliest, MAX(ended_at) AS latest FROM usage_segments"
            ).first
            let imported = try database.query(
                "SELECT COUNT(*) AS imported_count FROM imported_usage_history"
            ).first
            return MonitoringHistorySummary(
                eventCount: Int(usage?["event_count"]?.int64 ?? 0),
                earliestEventAt: usage?["earliest"]?.double.map { Date(timeIntervalSince1970: $0) },
                latestEventAt: usage?["latest"]?.double.map { Date(timeIntervalSince1970: $0) },
                importedAppCount: Int(imported?["imported_count"]?.int64 ?? 0)
            )
        }
    }

    public func deleteImportedUsageHistory() throws {
        try queue.sync {
            try database.execute("BEGIN IMMEDIATE")
            do {
                try database.execute("DELETE FROM imported_usage_days")
                try database.execute("DELETE FROM imported_usage_history")
                try database.execute("COMMIT")
            } catch {
                try? database.execute("ROLLBACK")
                throw error
            }
        }
    }

    @discardableResult
    public func deleteMonitoringHistory(before cutoff: Date? = nil) throws -> Int {
        try queue.sync {
            let beforeCount = Int(try database.query("SELECT COUNT(*) AS count FROM usage_segments").first?["count"]?.int64 ?? 0)
            try database.execute("BEGIN IMMEDIATE")
            do {
                if let cutoff {
                    try database.execute(
                        "DELETE FROM usage_segments WHERE ended_at < ?",
                        [.double(cutoff.timeIntervalSince1970)]
                    )
                    try database.execute(
                        "DELETE FROM imported_usage_days WHERE day_start < ?",
                        [.double(cutoff.timeIntervalSince1970)]
                    )
                } else {
                    try database.execute("DELETE FROM usage_segments")
                    try database.execute("DELETE FROM imported_usage_days")
                    try database.execute("DELETE FROM imported_usage_history")
                }
                try database.execute("COMMIT")
            } catch {
                try? database.execute("ROLLBACK")
                throw error
            }
            let afterCount = Int(try database.query("SELECT COUNT(*) AS count FROM usage_segments").first?["count"]?.int64 ?? 0)
            return beforeCount - afterCount
        }
    }

    public func replaceStorageItems(for appID: String, items: [StorageScanItem]) throws {
        try queue.sync {
            try database.execute("BEGIN IMMEDIATE")
            do {
                try database.execute("DELETE FROM storage_items WHERE app_id = ?", [.text(appID)])
                for item in items {
                    try database.execute(
                        """
                        INSERT INTO storage_items
                        (id, app_id, category, path, size_bytes, warning, scanned_at)
                        VALUES (?, ?, ?, ?, ?, ?, ?)
                        """,
                        [
                            .text(item.id),
                            .text(item.appID),
                            .text(item.category.rawValue),
                            .text(item.path),
                            .int64(item.sizeBytes),
                            item.warning.map(SQLiteValue.text) ?? .null,
                            .double(item.scannedAt.timeIntervalSince1970)
                        ]
                    )
                }
                try database.execute("COMMIT")
            } catch {
                try? database.execute("ROLLBACK")
                throw error
            }
        }
    }

    public func publishCompletedScanSnapshot(_ snapshot: CompletedAppScanSnapshot) throws {
        try queue.sync {
            let existingCleanup = try database.query("SELECT * FROM cleanup_suggestions")
                .compactMap(Self.cleanupSuggestion(from:))
                .reduce(into: [String: CleanupSuggestion]()) { $0[$1.id] = $1 }
            let existingLargeFiles = try database.query("SELECT * FROM large_files")
                .compactMap(Self.largeFile(from:))
                .reduce(into: [String: LargeFileRecord]()) { $0[$1.id] = $1 }

            try database.execute("BEGIN IMMEDIATE")
            do {
                for (appID, items) in snapshot.storageItemsByAppID {
                    try database.execute("DELETE FROM storage_items WHERE app_id = ?", [.text(appID)])
                    for item in items {
                        try database.execute(
                            """
                            INSERT INTO storage_items
                            (id, app_id, category, path, size_bytes, warning, scanned_at)
                            VALUES (?, ?, ?, ?, ?, ?, ?)
                            """,
                            [
                                .text(item.id), .text(item.appID), .text(item.category.rawValue),
                                .text(item.path), .int64(item.sizeBytes),
                                item.warning.map(SQLiteValue.text) ?? .null,
                                .double(item.scannedAt.timeIntervalSince1970)
                            ]
                        )
                    }
                }

                for (appID, findings) in snapshot.healthFindingsByAppID {
                    try database.execute("DELETE FROM health_findings WHERE app_id = ?", [.text(appID)])
                    for finding in findings { try insertHealthFinding(finding) }
                }

                for (appID, suggestions) in snapshot.cleanupSuggestionsByAppID {
                    try database.execute(
                        "DELETE FROM cleanup_suggestions WHERE app_id = ? AND state = ?",
                        [.text(appID), .text(CleanupSuggestionState.pending.rawValue)]
                    )
                    for suggestion in suggestions {
                        var next = suggestion
                        if let current = existingCleanup[suggestion.id], current.state != .pending {
                            next.state = current.state
                            next.quarantinePath = current.quarantinePath
                            next.updatedAt = current.updatedAt
                        }
                        try upsertCleanupSuggestion(next)
                    }
                }

                try database.execute("DELETE FROM large_files WHERE state = ?", [.text(LargeFileReviewState.needsReview.rawValue)])
                for record in snapshot.largeFiles {
                    var next = record
                    if let current = existingLargeFiles[record.id], current.state != .needsReview {
                        next.state = current.state
                    }
                    try upsertLargeFile(next)
                }
                try database.execute("COMMIT")
            } catch {
                try? database.execute("ROLLBACK")
                throw error
            }
        }
    }

    public func fetchStorageItems(appID: String) throws -> [StorageScanItem] {
        try queue.sync {
            try database.query(
                "SELECT * FROM storage_items WHERE app_id = ? ORDER BY category, path",
                [.text(appID)]
            ).compactMap(Self.storageItem(from:))
        }
    }

    public func fetchAllStorageItems() throws -> [StorageScanItem] {
        try queue.sync {
            try database.query("SELECT * FROM storage_items ORDER BY app_id, category, path")
                .compactMap(Self.storageItem(from:))
        }
    }

    public func replaceHealthFindings(for appID: String, findings: [AppHealthFinding]) throws {
        try queue.sync {
            try database.execute("BEGIN IMMEDIATE")
            do {
                try database.execute("DELETE FROM health_findings WHERE app_id = ?", [.text(appID)])
                for finding in findings {
                    try insertHealthFinding(finding)
                }
                try database.execute("COMMIT")
            } catch {
                try? database.execute("ROLLBACK")
                throw error
            }
        }
    }

    public func fetchHealthFindings() throws -> [AppHealthFinding] {
        try queue.sync {
            try database.query("SELECT * FROM health_findings ORDER BY checked_at DESC, title")
                .compactMap(Self.healthFinding(from:))
        }
    }

    public func replaceCleanupSuggestions(for appID: String, suggestions: [CleanupSuggestion]) throws {
        try queue.sync {
            let existing = try database.query("SELECT * FROM cleanup_suggestions WHERE app_id = ?", [.text(appID)])
                .compactMap(Self.cleanupSuggestion(from:))
                .reduce(into: [String: CleanupSuggestion]()) { partial, suggestion in
                    partial[suggestion.id] = suggestion
                }

            try database.execute("BEGIN IMMEDIATE")
            do {
                try database.execute(
                    "DELETE FROM cleanup_suggestions WHERE app_id = ? AND state = ?",
                    [.text(appID), .text(CleanupSuggestionState.pending.rawValue)]
                )

                for suggestion in suggestions {
                    var next = suggestion
                    if let current = existing[suggestion.id], current.state != .pending {
                        next.state = current.state
                        next.quarantinePath = current.quarantinePath
                        next.updatedAt = current.updatedAt
                    }
                    try upsertCleanupSuggestion(next)
                }
                try database.execute("COMMIT")
            } catch {
                try? database.execute("ROLLBACK")
                throw error
            }
        }
    }

    public func fetchCleanupSuggestions() throws -> [CleanupSuggestion] {
        try queue.sync {
            try database.query("SELECT * FROM cleanup_suggestions ORDER BY updated_at DESC, size_bytes DESC")
                .compactMap(Self.cleanupSuggestion(from:))
        }
    }

    public func saveCleanupSuggestion(_ suggestion: CleanupSuggestion) throws {
        try queue.sync {
            try upsertCleanupSuggestion(suggestion)
        }
    }

    public func updateCleanupSuggestion(
        id: String,
        state: CleanupSuggestionState,
        quarantinePath: String? = nil,
        updatedAt: Date = Date()
    ) throws {
        try queue.sync {
            try database.execute(
                """
                UPDATE cleanup_suggestions
                SET state = ?, quarantine_path = ?, updated_at = ?
                WHERE id = ?
                """,
                [
                    .text(state.rawValue),
                    quarantinePath.map(SQLiteValue.text) ?? .null,
                    .double(updatedAt.timeIntervalSince1970),
                    .text(id)
                ]
            )
        }
    }

    public func replaceLargeFiles(_ records: [LargeFileRecord]) throws {
        try queue.sync {
            let existing = try database.query("SELECT * FROM large_files")
                .compactMap(Self.largeFile(from:))
                .reduce(into: [String: LargeFileRecord]()) { partial, record in
                    partial[record.id] = record
                }

            try database.execute("BEGIN IMMEDIATE")
            do {
                try database.execute("DELETE FROM large_files WHERE state = ?", [.text(LargeFileReviewState.needsReview.rawValue)])
                for record in records {
                    var next = record
                    if let current = existing[record.id], current.state != .needsReview {
                        next.state = current.state
                    }
                    try upsertLargeFile(next)
                }
                try database.execute("COMMIT")
            } catch {
                try? database.execute("ROLLBACK")
                throw error
            }
        }
    }

    public func fetchLargeFiles() throws -> [LargeFileRecord] {
        try queue.sync {
            try database.query("SELECT * FROM large_files ORDER BY size_bytes DESC, path")
                .compactMap(Self.largeFile(from:))
        }
    }

    public func updateLargeFileState(id: String, state: LargeFileReviewState) throws {
        try queue.sync {
            try database.execute(
                "UPDATE large_files SET state = ? WHERE id = ?",
                [.text(state.rawValue), .text(id)]
            )
        }
    }

    public func setTags(_ tags: [String], for appID: String) throws {
        try queue.sync {
            try database.execute("BEGIN IMMEDIATE")
            do {
                try database.execute("DELETE FROM app_tags WHERE app_id = ?", [.text(appID)])
                for tag in Set(tags.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }) {
                    try database.execute(
                        "INSERT OR IGNORE INTO app_tags (app_id, tag) VALUES (?, ?)",
                        [.text(appID), .text(tag)]
                    )
                }
                try database.execute("COMMIT")
            } catch {
                try? database.execute("ROLLBACK")
                throw error
            }
        }
    }

    public func fetchTagsByApp() throws -> [String: [String]] {
        try queue.sync {
            var tags: [String: [String]] = [:]
            for row in try database.query("SELECT * FROM app_tags ORDER BY lower(tag)") {
                guard let appID = row["app_id"]?.string, let tag = row["tag"]?.string else { continue }
                tags[appID, default: []].append(tag)
            }
            return tags
        }
    }

    public func setIgnored(_ ignored: Bool, appID: String) throws {
        try queue.sync {
            if ignored {
                try database.execute(
                    "INSERT OR REPLACE INTO ignored_apps (app_id, ignored_at) VALUES (?, ?)",
                    [.text(appID), .double(Date().timeIntervalSince1970)]
                )
            } else {
                try database.execute("DELETE FROM ignored_apps WHERE app_id = ?", [.text(appID)])
            }
        }
    }

    public func fetchIgnoredAppIDs() throws -> Set<String> {
        try queue.sync {
            Set(try database.query("SELECT app_id FROM ignored_apps").compactMap { $0["app_id"]?.string })
        }
    }

    public func recordAction(title: String, detail: String, date: Date = Date()) throws {
        try queue.sync {
            try database.execute(
                """
                INSERT INTO action_history (id, title, detail, created_at)
                VALUES (?, ?, ?, ?)
                """,
                [
                    .text(UUID().uuidString),
                    .text(title),
                    .text(detail),
                    .double(date.timeIntervalSince1970)
                ]
            )
        }
    }

    public func fetchActionHistory(limit: Int = 200) throws -> [(Date, String, String)] {
        try queue.sync {
            try database.query(
                "SELECT * FROM action_history ORDER BY created_at DESC LIMIT ?",
                [.int64(Int64(limit))]
            ).compactMap { row in
                guard
                    let createdAt = row["created_at"]?.double,
                    let title = row["title"]?.string,
                    let detail = row["detail"]?.string
                else {
                    return nil
                }
                return (Date(timeIntervalSince1970: createdAt), title, detail)
            }
        }
    }

    public func upsertWarningTriageRecord(
        warning: AppWarningItem,
        disposition: AppWarningDisposition,
        action: String,
        detail: String,
        date: Date = Date()
    ) throws {
        try queue.sync {
            let existing = try database.query(
                "SELECT first_seen_at FROM warning_triage WHERE warning_id = ?",
                [.text(warning.id)]
            ).first
            let firstSeenAt = existing?["first_seen_at"]?.double.map(Date.init(timeIntervalSince1970:)) ?? warning.detectedAt
            let snapshotData = try JSONEncoder().encode(warning)
            guard let snapshotJSON = String(data: snapshotData, encoding: .utf8) else {
                throw CocoaError(.fileWriteInapplicableStringEncoding)
            }

            try database.execute("BEGIN IMMEDIATE")
            do {
                try database.execute(
                    """
                    INSERT INTO warning_triage
                    (warning_id, disposition, snapshot_json, first_seen_at, last_seen_at, updated_at)
                    VALUES (?, ?, ?, ?, ?, ?)
                    ON CONFLICT(warning_id) DO UPDATE SET
                        disposition = excluded.disposition,
                        snapshot_json = excluded.snapshot_json,
                        last_seen_at = excluded.last_seen_at,
                        updated_at = excluded.updated_at
                    """,
                    [
                        .text(warning.id),
                        .text(disposition.rawValue),
                        .text(snapshotJSON),
                        .double(firstSeenAt.timeIntervalSince1970),
                        .double(max(warning.detectedAt, date).timeIntervalSince1970),
                        .double(date.timeIntervalSince1970)
                    ]
                )
                try database.execute(
                    """
                    INSERT INTO warning_triage_history (id, warning_id, action, detail, created_at)
                    VALUES (?, ?, ?, ?, ?)
                    """,
                    [.text(UUID().uuidString), .text(warning.id), .text(action), .text(detail), .double(date.timeIntervalSince1970)]
                )
                try database.execute("COMMIT")
            } catch {
                try? database.execute("ROLLBACK")
                throw error
            }
        }
    }

    public func recordWarningTriageEvent(
        warning: AppWarningItem,
        action: String,
        detail: String,
        date: Date = Date()
    ) throws {
        try queue.sync {
            try database.execute(
                """
                INSERT INTO warning_triage_history (id, warning_id, action, detail, created_at)
                VALUES (?, ?, ?, ?, ?)
                """,
                [.text(UUID().uuidString), .text(warning.id), .text(action), .text(detail), .double(date.timeIntervalSince1970)]
            )
        }
    }

    public func fetchWarningTriageRecords() throws -> [AppWarningTriageRecord] {
        try queue.sync {
            try database.query("SELECT * FROM warning_triage ORDER BY updated_at DESC").compactMap { row in
                guard
                    let warningID = row["warning_id"]?.string,
                    let dispositionValue = row["disposition"]?.string,
                    let disposition = AppWarningDisposition(rawValue: dispositionValue),
                    let snapshotJSON = row["snapshot_json"]?.string,
                    let snapshotData = snapshotJSON.data(using: .utf8),
                    let snapshot = try? JSONDecoder().decode(AppWarningItem.self, from: snapshotData),
                    let firstSeenAt = row["first_seen_at"]?.double,
                    let lastSeenAt = row["last_seen_at"]?.double,
                    let updatedAt = row["updated_at"]?.double
                else { return nil }
                return AppWarningTriageRecord(
                    warningID: warningID,
                    disposition: disposition,
                    snapshot: snapshot,
                    firstSeenAt: Date(timeIntervalSince1970: firstSeenAt),
                    lastSeenAt: Date(timeIntervalSince1970: lastSeenAt),
                    updatedAt: Date(timeIntervalSince1970: updatedAt)
                )
            }
        }
    }

    public func fetchWarningTriageHistory(limit: Int = 1_000) throws -> [AppWarningTriageEvent] {
        try queue.sync {
            try database.query(
                "SELECT * FROM warning_triage_history ORDER BY created_at DESC LIMIT ?",
                [.int64(Int64(limit))]
            ).compactMap { row in
                guard
                    let id = row["id"]?.string,
                    let warningID = row["warning_id"]?.string,
                    let action = row["action"]?.string,
                    let detail = row["detail"]?.string,
                    let createdAt = row["created_at"]?.double
                else { return nil }
                return AppWarningTriageEvent(
                    id: id,
                    warningID: warningID,
                    action: action,
                    detail: detail,
                    createdAt: Date(timeIntervalSince1970: createdAt)
                )
            }
        }
    }

    public func recordUninstallRun(_ run: UninstallRunRecord, itemResults: [UninstallItemResult]) throws {
        try queue.sync {
            try database.execute("BEGIN IMMEDIATE")
            do {
                try insertUninstallRun(run)
                for result in itemResults {
                    try insertUninstallItemResult(result)
                }
                try database.execute("COMMIT")
            } catch {
                try? database.execute("ROLLBACK")
                throw error
            }
        }
    }

    public func fetchUninstallRuns(limit: Int = 100) throws -> [UninstallRunRecord] {
        try queue.sync {
            try database.query(
                "SELECT * FROM uninstall_runs ORDER BY completed_at DESC LIMIT ?",
                [.int64(Int64(limit))]
            ).compactMap(Self.uninstallRun(from:))
        }
    }

    public func fetchUninstallItemResults(runID: String) throws -> [UninstallItemResult] {
        try queue.sync {
            try database.query(
                "SELECT * FROM uninstall_item_results WHERE run_id = ? ORDER BY completed_at, path",
                [.text(runID)]
            ).compactMap(Self.uninstallItemResult(from:))
        }
    }

    public func replaceAppUpdates(_ records: [AppUpdateRecord]) throws {
        try queue.sync {
            try database.execute("BEGIN IMMEDIATE")
            do {
                try database.execute("DELETE FROM app_updates")
                for record in records {
                    try insertAppUpdate(record)
                }
                try database.execute("COMMIT")
            } catch {
                try? database.execute("ROLLBACK")
                throw error
            }
        }
    }

    public func fetchAppUpdates() throws -> [AppUpdateRecord] {
        try queue.sync {
            try database.query("SELECT * FROM app_updates ORDER BY checked_at DESC, lower(app_name)")
                .compactMap(Self.appUpdate(from:))
        }
    }

    public func upsertChangeLogEntries(_ entries: [AppChangeLogEntry]) throws {
        guard !entries.isEmpty else { return }
        try queue.sync {
            try database.execute("BEGIN IMMEDIATE")
            do {
                for entry in entries {
                    try upsertChangeLogEntry(entry)
                }
                try database.execute("COMMIT")
            } catch {
                try? database.execute("ROLLBACK")
                throw error
            }
        }
    }

    public func fetchChangeLogEntries(limit: Int = 300) throws -> [AppChangeLogEntry] {
        try queue.sync {
            try database.query(
                "SELECT * FROM app_changelogs ORDER BY captured_at DESC LIMIT ?",
                [.int64(Int64(limit))]
            ).compactMap(Self.changeLogEntry(from:))
        }
    }

    public func fetchChangeLogEntries(appID: String, limit: Int = 50) throws -> [AppChangeLogEntry] {
        try queue.sync {
            try database.query(
                "SELECT * FROM app_changelogs WHERE app_id = ? ORDER BY captured_at DESC LIMIT ?",
                [.text(appID), .int64(Int64(limit))]
            ).compactMap(Self.changeLogEntry(from:))
        }
    }

    public func recordUpdateRun(_ run: UpdateRunRecord, itemResults: [UpdateItemResult]) throws {
        try queue.sync {
            try database.execute("BEGIN IMMEDIATE")
            do {
                try insertUpdateRun(run)
                for result in itemResults {
                    try insertUpdateItemResult(result)
                }
                try database.execute("COMMIT")
            } catch {
                try? database.execute("ROLLBACK")
                throw error
            }
        }
    }

    public func fetchUpdateRuns(limit: Int = 100) throws -> [UpdateRunRecord] {
        try queue.sync {
            try database.query(
                "SELECT * FROM update_runs ORDER BY completed_at DESC LIMIT ?",
                [.int64(Int64(limit))]
            ).compactMap(Self.updateRun(from:))
        }
    }

    public func fetchUpdateItemResults(limit: Int = 200) throws -> [UpdateItemResult] {
        try queue.sync {
            try database.query(
                "SELECT * FROM update_item_results ORDER BY completed_at DESC LIMIT ?",
                [.int64(Int64(limit))]
            ).compactMap(Self.updateItemResult(from:))
        }
    }

    public func fetchSavedFilters() throws -> [SavedAppFilter] {
        guard let value = try setting("saved_filters"), let data = value.data(using: .utf8) else {
            return []
        }
        return (try? JSONDecoder().decode([SavedAppFilter].self, from: data)) ?? []
    }

    public func saveSavedFilters(_ filters: [SavedAppFilter]) throws {
        let data = try JSONEncoder().encode(filters)
        try setSetting("saved_filters", value: String(data: data, encoding: .utf8) ?? "[]")
    }

    public func fetchScanSchedule() throws -> AppScanSchedule {
        guard let value = try setting("scan_schedule"), let data = value.data(using: .utf8) else {
            return AppScanSchedule()
        }
        return (try? JSONDecoder().decode(AppScanSchedule.self, from: data)) ?? AppScanSchedule()
    }

    public func saveScanSchedule(_ schedule: AppScanSchedule) throws {
        let data = try JSONEncoder().encode(schedule)
        try setSetting("scan_schedule", value: String(data: data, encoding: .utf8) ?? "{}")
    }

    public func fetchUpdateSettings() throws -> AppUpdateSettings {
        guard let value = try setting("update_settings"), let data = value.data(using: .utf8) else {
            return AppUpdateSettings()
        }
        return (try? JSONDecoder().decode(AppUpdateSettings.self, from: data)) ?? AppUpdateSettings()
    }

    public func saveUpdateSettings(_ settings: AppUpdateSettings) throws {
        let data = try JSONEncoder().encode(settings)
        try setSetting("update_settings", value: String(data: data, encoding: .utf8) ?? "{}")
    }

    public func replaceImportedUsage(_ imports: [ImportedUsageHistory]) throws {
        try queue.sync {
            try database.execute("BEGIN IMMEDIATE")
            do {
                for imported in imports {
                    try database.execute("DELETE FROM imported_usage_history WHERE app_id = ?", [.text(imported.appID)])
                    try database.execute("DELETE FROM imported_usage_days WHERE app_id = ?", [.text(imported.appID)])

                    try database.execute(
                        """
                        INSERT INTO imported_usage_history
                        (app_id, last_used, use_count, imported_at)
                        VALUES (?, ?, ?, ?)
                        """,
                        [
                            .text(imported.appID),
                            imported.lastUsed.map { SQLiteValue.double($0.timeIntervalSince1970) } ?? .null,
                            imported.useCount.map(SQLiteValue.int64) ?? .null,
                            .double(imported.importedAt.timeIntervalSince1970)
                        ]
                    )

                    for day in Set(imported.usedDays) {
                        try database.execute(
                            """
                            INSERT OR IGNORE INTO imported_usage_days
                            (app_id, day_start)
                            VALUES (?, ?)
                            """,
                            [.text(imported.appID), .double(day.timeIntervalSince1970)]
                        )
                    }
                }
                try database.execute("COMMIT")
            } catch {
                try? database.execute("ROLLBACK")
                throw error
            }
        }
    }

    public func fetchRows(period: ReportingPeriod, includeAll: Bool, now: Date = Date(), calendar: Calendar = .current) throws -> [AppUsageRow] {
        let apps = try fetchApps(includeAll: includeAll)
        let interval = period.interval(now: now, calendar: calendar)
        let usage = try usageTotals(start: interval.start, end: interval.end, calendar: calendar)
        let storage = try storageTotals()
        let imported = try importedUsageTotals(start: interval.start, end: interval.end, calendar: calendar)
        let trackingStartedAt = try setting("tracking_started_at")
            .flatMap(TimeInterval.init)
            .map(Date.init(timeIntervalSince1970:))
        let verifiedInactivityDays = max(1, try setting("verified_inactivity_days").flatMap(Int.init) ?? 30)

        return apps.map { app in
            let appUsage = usage[app.id] ?? UsageAccumulator()
            let appStorage = storage[app.id] ?? StorageTotals()
            let appImported = imported[app.id] ?? ImportedUsageTotals()
            return AppUsageRow(
                app: app,
                usageSeconds: appUsage.seconds,
                lastUsed: appUsage.lastUsed,
                bundleSizeBytes: appStorage.bundleSizeBytes,
                relatedSizeBytes: appStorage.relatedSizeBytes,
                warningCount: appStorage.warningCount,
                scannedAt: appStorage.scannedAt,
                importedLastUsed: appImported.lastUsed,
                importedUseCount: appImported.useCount,
                importedDaysInPeriod: appImported.daysInPeriod,
                importedAt: appImported.importedAt,
                trackingStartedAt: trackingStartedAt,
                verifiedInactivityDays: verifiedInactivityDays,
                activityEvaluatedAt: now
            )
        }
    }

    public func dailyUsageRows(period: ReportingPeriod, includeAll: Bool, now: Date = Date(), calendar: Calendar = .current) throws -> [DailyUsageRow] {
        let appsByID = Dictionary(uniqueKeysWithValues: try fetchApps(includeAll: includeAll).map { ($0.id, $0) })
        let interval = period.interval(now: now, calendar: calendar)
        let segments = try fetchOverlappingSegments(start: interval.start, end: interval.end)
        var totals: [String: [Date: TimeInterval]] = [:]

        for segment in segments {
            guard appsByID[segment.appID] != nil else { continue }
            let clippedStart = max(segment.startedAt, interval.start)
            let clippedEnd = min(segment.endedAt, interval.end)
            guard clippedEnd > clippedStart else { continue }

            var cursor = calendar.startOfDay(for: clippedStart)
            while cursor < clippedEnd {
                guard let nextDay = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
                let sliceStart = max(clippedStart, cursor)
                let sliceEnd = min(clippedEnd, nextDay)
                if sliceEnd > sliceStart {
                    totals[segment.appID, default: [:]][cursor, default: 0] += sliceEnd.timeIntervalSince(sliceStart)
                }
                cursor = nextDay
            }
        }

        return totals.flatMap { appID, dayTotals -> [DailyUsageRow] in
            guard let app = appsByID[appID] else { return [] }
            return dayTotals.map { day, seconds in
                DailyUsageRow(day: day, appID: appID, appName: app.name, usageSeconds: seconds)
            }
        }
        .sorted { lhs, rhs in
            if lhs.day == rhs.day { return lhs.appName < rhs.appName }
            return lhs.day < rhs.day
        }
    }

    public func usageSegments(period: ReportingPeriod, includeAll: Bool, now: Date = Date(), calendar: Calendar = .current) throws -> [UsageSegment] {
        let allowedAppIDs = Set(try fetchApps(includeAll: includeAll).map(\.id))
        let interval = period.interval(now: now, calendar: calendar)
        return try fetchOverlappingSegments(start: interval.start, end: interval.end)
            .filter { allowedAppIDs.contains($0.appID) }
            .sorted { lhs, rhs in
                if lhs.startedAt == rhs.startedAt { return lhs.appName < rhs.appName }
                return lhs.startedAt > rhs.startedAt
            }
    }

    public func timelineSessions(
        period: ReportingPeriod,
        includeAll: Bool,
        now: Date = Date(),
        calendar: Calendar = .current,
        allowedAppIDs requestedAppIDs: Set<String>? = nil
    ) throws -> [TimelineSession] {
        let allowedAppIDs = try timelineAllowedAppIDs(includeAll: includeAll, requestedAppIDs: requestedAppIDs)
        guard !allowedAppIDs.isEmpty else { return [] }
        let interval = period.interval(now: now, calendar: calendar)
        let rawSegments = try fetchOverlappingSegments(start: interval.start, end: interval.end)
        return TimelineDataBuilder.clippedSessions(
            from: rawSegments,
            interval: interval,
            calendar: calendar,
            allowedAppIDs: allowedAppIDs
        )
    }

    public func timelineDayGroups(
        period: ReportingPeriod,
        includeAll: Bool,
        now: Date = Date(),
        calendar: Calendar = .current,
        allowedAppIDs requestedAppIDs: Set<String>? = nil
    ) throws -> [TimelineDayGroup] {
        try TimelineDataBuilder.dayGroups(
            from: timelineSessions(
                period: period,
                includeAll: includeAll,
                now: now,
                calendar: calendar,
                allowedAppIDs: requestedAppIDs
            ),
            calendar: calendar
        )
    }

    public func timelineSummary(
        period: ReportingPeriod,
        includeAll: Bool,
        now: Date = Date(),
        calendar: Calendar = .current,
        allowedAppIDs requestedAppIDs: Set<String>? = nil
    ) throws -> TimelineSummary {
        let allowedAppIDs = try timelineAllowedAppIDs(includeAll: includeAll, requestedAppIDs: requestedAppIDs)
        let interval = period.interval(now: now, calendar: calendar)
        let previousInterval = TimelineDataBuilder.previousInterval(
            for: period,
            currentInterval: interval,
            calendar: calendar
        )

        let currentRawSegments = try fetchOverlappingSegments(start: interval.start, end: interval.end)
        let previousRawSegments = try fetchOverlappingSegments(start: previousInterval.start, end: previousInterval.end)
        let sessions = TimelineDataBuilder.clippedSessions(
            from: currentRawSegments,
            interval: interval,
            calendar: calendar,
            allowedAppIDs: allowedAppIDs
        )
        let previousSessions = TimelineDataBuilder.clippedSessions(
            from: previousRawSegments,
            interval: previousInterval,
            calendar: calendar,
            allowedAppIDs: allowedAppIDs
        )

        return TimelineDataBuilder.summary(
            sessions: sessions,
            previousSessions: previousSessions,
            interval: interval,
            previousInterval: previousInterval,
            calendar: calendar
        )
    }

    public func timelineHourBuckets(
        period: ReportingPeriod,
        includeAll: Bool,
        now: Date = Date(),
        calendar: Calendar = .current,
        allowedAppIDs requestedAppIDs: Set<String>? = nil
    ) throws -> [TimelineHourBucket] {
        try TimelineDataBuilder.hourBuckets(
            from: timelineSessions(
                period: period,
                includeAll: includeAll,
                now: now,
                calendar: calendar,
                allowedAppIDs: requestedAppIDs
            ),
            calendar: calendar
        )
    }

    public func usageAnalytics(
        period: ReportingPeriod,
        includeAll: Bool,
        grouping: UsageTrendGrouping? = nil,
        now: Date = Date(),
        calendar: Calendar = .current,
        includedAppIDs: Set<String>? = nil,
        excludedAppIDs: Set<String> = [],
        visibleAppLimit: Int = 5
    ) throws -> UsageAnalyticsSnapshot {
        let resolvedGrouping = grouping ?? UsageTrendGrouping.defaultGrouping(for: period)
        let interval = period.interval(now: now, calendar: calendar)
        let previousInterval = Self.previousEquivalentInterval(for: interval)
        let allowedAppIDs = try analyticsAllowedAppIDs(
            includeAll: includeAll,
            includedAppIDs: includedAppIDs,
            excludedAppIDs: excludedAppIDs
        )
        let currentSlices = try usageSlices(start: interval.start, end: interval.end, allowedAppIDs: allowedAppIDs)
        let previousSlices = try usageSlices(
            start: previousInterval.start,
            end: previousInterval.end,
            allowedAppIDs: allowedAppIDs
        )
        let topApps = Self.topApps(from: currentSlices)
        let summary = Self.analyticsSummary(
            currentSlices: currentSlices,
            previousSlices: previousSlices,
            interval: interval,
            previousInterval: previousInterval,
            topApps: topApps,
            calendar: calendar
        )
        let visibleTopAppIDs = topApps.prefix(max(1, visibleAppLimit)).map(\.appID)
        let buckets = Self.trendBuckets(
            from: currentSlices,
            interval: interval,
            grouping: resolvedGrouping,
            visibleTopAppIDs: visibleTopAppIDs,
            topApps: topApps,
            calendar: calendar
        )
        let heatmapCells = Self.heatmapCells(
            from: currentSlices,
            period: period,
            interval: interval,
            calendar: calendar
        )

        return UsageAnalyticsSnapshot(
            interval: interval,
            grouping: resolvedGrouping,
            summary: summary,
            trendBuckets: buckets,
            heatmapCells: heatmapCells,
            topApps: topApps
        )
    }

    public func usageAnalyticsSummary(
        period: ReportingPeriod,
        includeAll: Bool,
        now: Date = Date(),
        calendar: Calendar = .current,
        includedAppIDs: Set<String>? = nil,
        excludedAppIDs: Set<String> = []
    ) throws -> UsageAnalyticsSummary {
        try usageAnalytics(
            period: period,
            includeAll: includeAll,
            now: now,
            calendar: calendar,
            includedAppIDs: includedAppIDs,
            excludedAppIDs: excludedAppIDs
        ).summary
    }

    public func topAppUsage(
        period: ReportingPeriod,
        includeAll: Bool,
        now: Date = Date(),
        calendar: Calendar = .current,
        includedAppIDs: Set<String>? = nil,
        excludedAppIDs: Set<String> = []
    ) throws -> [TopAppUsage] {
        try usageAnalytics(
            period: period,
            includeAll: includeAll,
            now: now,
            calendar: calendar,
            includedAppIDs: includedAppIDs,
            excludedAppIDs: excludedAppIDs
        ).topApps
    }

    public func usageTrendBuckets(
        period: ReportingPeriod,
        includeAll: Bool,
        grouping: UsageTrendGrouping? = nil,
        now: Date = Date(),
        calendar: Calendar = .current,
        includedAppIDs: Set<String>? = nil,
        excludedAppIDs: Set<String> = [],
        visibleAppLimit: Int = 5
    ) throws -> [UsageTrendBucket] {
        try usageAnalytics(
            period: period,
            includeAll: includeAll,
            grouping: grouping,
            now: now,
            calendar: calendar,
            includedAppIDs: includedAppIDs,
            excludedAppIDs: excludedAppIDs,
            visibleAppLimit: visibleAppLimit
        ).trendBuckets
    }

    public func usageHeatmapCells(
        period: ReportingPeriod,
        includeAll: Bool,
        now: Date = Date(),
        calendar: Calendar = .current,
        includedAppIDs: Set<String>? = nil,
        excludedAppIDs: Set<String> = []
    ) throws -> [UsageHeatmapCell] {
        try usageAnalytics(
            period: period,
            includeAll: includeAll,
            now: now,
            calendar: calendar,
            includedAppIDs: includedAppIDs,
            excludedAppIDs: excludedAppIDs
        ).heatmapCells
    }

    public func setSetting(_ key: String, value: String) throws {
        try queue.sync {
            try database.execute(
                """
                INSERT INTO settings (key, value) VALUES (?, ?)
                ON CONFLICT(key) DO UPDATE SET value = excluded.value
                """,
                [.text(key), .text(value)]
            )
        }
    }

    public func setting(_ key: String) throws -> String? {
        try queue.sync {
            try database.query("SELECT value FROM settings WHERE key = ?", [.text(key)])
                .first?["value"]?.string
        }
    }

    private func usageTotals(start: Date, end: Date, calendar: Calendar) throws -> [String: UsageAccumulator] {
        let segments = try fetchOverlappingSegments(start: start, end: end)
        var totals: [String: UsageAccumulator] = [:]
        for segment in segments {
            let clippedStart = max(segment.startedAt, start)
            let clippedEnd = min(segment.endedAt, end)
            guard clippedEnd > clippedStart else { continue }
            totals[segment.appID, default: UsageAccumulator()].seconds += clippedEnd.timeIntervalSince(clippedStart)
            totals[segment.appID, default: UsageAccumulator()].lastUsed = max(
                totals[segment.appID]?.lastUsed ?? .distantPast,
                clippedEnd
            )
        }
        return totals
    }

    private func timelineAllowedAppIDs(includeAll: Bool, requestedAppIDs: Set<String>?) throws -> Set<String> {
        let allAllowed = Set(try fetchApps(includeAll: includeAll).map(\.id))
        guard let requestedAppIDs else { return allAllowed }
        return allAllowed.intersection(requestedAppIDs)
    }

    private func unusedStoragePassAnalyticsAllowedAppIDs(
        includeAll: Bool,
        includedAppIDs: Set<String>?,
        excludedAppIDs: Set<String>
    ) throws -> Set<String> {
        var allowed = Set(try fetchApps(includeAll: includeAll).map(\.id))
        if let includedAppIDs {
            allowed.formIntersection(includedAppIDs)
        }
        allowed.subtract(excludedAppIDs)
        return allowed
    }

    private func unusedStoragePassUsageSlices(start: Date, end: Date, allowedAppIDs: Set<String>) throws -> [UsageAnalyticsSlice] {
        guard !allowedAppIDs.isEmpty else { return [] }

        return try fetchOverlappingSegments(start: start, end: end).compactMap { segment in
            guard allowedAppIDs.contains(segment.appID) else { return nil }
            let clippedStart = max(segment.startedAt, start)
            let clippedEnd = min(segment.endedAt, end)
            guard clippedEnd > clippedStart else { return nil }
            return UsageAnalyticsSlice(
                appID: segment.appID,
                appName: segment.appName,
                appPath: segment.appPath,
                startedAt: clippedStart,
                endedAt: clippedEnd
            )
        }
    }

    private static func unusedStoragePassPreviousEquivalentInterval(for interval: DateInterval) -> DateInterval {
        let duration = max(interval.duration, 1)
        return DateInterval(
            start: interval.start.addingTimeInterval(-duration),
            end: interval.start
        )
    }

    private static func topApps(from slices: [UsageAnalyticsSlice]) -> [TopAppUsage] {
        let totalSeconds = max(slices.reduce(0) { $0 + $1.seconds }, 1)
        let grouped = Dictionary(grouping: slices, by: \.appID)

        return grouped.compactMap { appID, appSlices -> TopAppUsage? in
            guard let first = appSlices.first else { return nil }
            let seconds = appSlices.reduce(0) { $0 + $1.seconds }
            return TopAppUsage(
                appID: appID,
                appName: first.appName,
                appPath: first.appPath,
                seconds: seconds,
                percentOfTotal: seconds / totalSeconds
            )
        }
        .sorted { lhs, rhs in
            if lhs.seconds == rhs.seconds {
                return lhs.appName.localizedCaseInsensitiveCompare(rhs.appName) == .orderedAscending
            }
            return lhs.seconds > rhs.seconds
        }
    }

    private static func analyticsSummary(
        currentSlices: [UsageAnalyticsSlice],
        previousSlices: [UsageAnalyticsSlice],
        interval: DateInterval,
        previousInterval: DateInterval,
        topApps: [TopAppUsage],
        calendar: Calendar
    ) -> UsageAnalyticsSummary {
        let totalSeconds = currentSlices.reduce(0) { $0 + $1.seconds }
        let previousTotalSeconds = previousSlices.reduce(0) { $0 + $1.seconds }
        let dayCount = representedDayCount(in: interval, calendar: calendar)
        let previousDayCount = representedDayCount(in: previousInterval, calendar: calendar)
        let dailyAverage = totalSeconds / TimeInterval(dayCount)
        let previousDailyAverage = previousTotalSeconds / TimeInterval(previousDayCount)
        let currentDayTotals = dayTotals(from: currentSlices, calendar: calendar)
        let peak = currentDayTotals.max { lhs, rhs in
            if lhs.value == rhs.value { return lhs.key < rhs.key }
            return lhs.value < rhs.value
        }

        let comparison = UsagePeriodComparison(
            previousTotalSeconds: previousTotalSeconds,
            totalDeltaSeconds: totalSeconds - previousTotalSeconds,
            totalPercentChange: percentChange(current: totalSeconds, previous: previousTotalSeconds),
            previousDailyAverageSeconds: previousDailyAverage,
            dailyAverageDeltaSeconds: dailyAverage - previousDailyAverage,
            dailyAveragePercentChange: percentChange(current: dailyAverage, previous: previousDailyAverage),
            previousSessionCount: previousSlices.count,
            sessionDelta: currentSlices.count - previousSlices.count,
            sessionPercentChange: percentChange(current: Double(currentSlices.count), previous: Double(previousSlices.count))
        )

        return UsageAnalyticsSummary(
            totalSeconds: totalSeconds,
            dailyAverageSeconds: dailyAverage,
            peakDay: peak?.key,
            peakDaySeconds: peak?.value ?? 0,
            mostUsedApp: topApps.first,
            sessionCount: currentSlices.count,
            comparison: comparison
        )
    }

    private static func trendBuckets(
        from slices: [UsageAnalyticsSlice],
        interval: DateInterval,
        grouping: UsageTrendGrouping,
        visibleTopAppIDs: [String],
        topApps: [TopAppUsage],
        calendar: Calendar
    ) -> [UsageTrendBucket] {
        let visibleSet = Set(visibleTopAppIDs)
        let topAppLookup = Dictionary(uniqueKeysWithValues: topApps.map { ($0.appID, $0) })

        return bucketIntervals(for: interval, grouping: grouping, calendar: calendar).map { bucket in
            var totalsByAppID: [String: TimeInterval] = [:]
            for slice in slices {
                let seconds = overlapSeconds(sliceStart: slice.startedAt, sliceEnd: slice.endedAt, interval: bucket)
                guard seconds > 0 else { continue }
                totalsByAppID[slice.appID, default: 0] += seconds
            }

            let bucketTotal = totalsByAppID.values.reduce(0, +)
            var stacks: [UsageStackSegment] = []
            for appID in visibleTopAppIDs {
                guard let seconds = totalsByAppID[appID], seconds > 0 else { continue }
                let app = topAppLookup[appID]
                stacks.append(UsageStackSegment(
                    id: "\(Int(bucket.start.timeIntervalSince1970))|\(appID)",
                    appID: appID,
                    appName: app?.appName ?? appID,
                    appPath: app?.appPath ?? "",
                    seconds: seconds,
                    percentOfBucket: bucketTotal > 0 ? seconds / bucketTotal : 0
                ))
            }

            let otherSeconds = totalsByAppID
                .filter { !visibleSet.contains($0.key) }
                .values
                .reduce(0, +)
            if otherSeconds > 0 {
                stacks.append(UsageStackSegment(
                    id: "\(Int(bucket.start.timeIntervalSince1970))|other",
                    appID: "other",
                    appName: "Other",
                    appPath: "",
                    seconds: otherSeconds,
                    percentOfBucket: bucketTotal > 0 ? otherSeconds / bucketTotal : 0,
                    isOther: true
                ))
            }

            return UsageTrendBucket(
                id: "\(Int(bucket.start.timeIntervalSince1970))",
                start: bucket.start,
                end: bucket.end,
                stacks: stacks,
                totalSeconds: bucketTotal
            )
        }
    }

    private static func heatmapCells(
        from slices: [UsageAnalyticsSlice],
        period: ReportingPeriod,
        interval: DateInterval,
        calendar: Calendar
    ) -> [UsageHeatmapCell] {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.dateFormat = period == .today ? "ha" : "EEE M/d"

        var cells: [UsageHeatmapCell] = []
        var dayStart = calendar.startOfDay(for: interval.start)

        while dayStart < interval.end {
            for hour in 0..<24 {
                guard let hourStart = calendar.date(byAdding: .hour, value: hour, to: dayStart),
                      let hourEnd = calendar.date(byAdding: .hour, value: 1, to: hourStart)
                else { continue }
                let hourInterval = DateInterval(start: hourStart, end: hourEnd)
                var totalSeconds: TimeInterval = 0
                var appTotals: [String: TimeInterval] = [:]
                var appNames: [String: String] = [:]
                var sessionCount = 0

                for slice in slices {
                    let seconds = overlapSeconds(sliceStart: slice.startedAt, sliceEnd: slice.endedAt, interval: hourInterval)
                    guard seconds > 0 else { continue }
                    totalSeconds += seconds
                    appTotals[slice.appID, default: 0] += seconds
                    appNames[slice.appID] = slice.appName
                    sessionCount += 1
                }

                let topApp = appTotals.max { lhs, rhs in
                    if lhs.value == rhs.value {
                        return (appNames[lhs.key] ?? lhs.key) > (appNames[rhs.key] ?? rhs.key)
                    }
                    return lhs.value < rhs.value
                }

                cells.append(UsageHeatmapCell(
                    id: "\(Int(dayStart.timeIntervalSince1970))|\(hour)",
                    rowStart: dayStart,
                    rowLabel: formatter.string(from: dayStart),
                    hourOfDay: hour,
                    seconds: totalSeconds,
                    sessionCount: sessionCount,
                    topAppID: topApp?.key,
                    topAppName: topApp.flatMap { appNames[$0.key] }
                ))
            }

            guard let nextDay = calendar.date(byAdding: .day, value: 1, to: dayStart) else { break }
            dayStart = nextDay
        }

        return cells
    }

    private static func bucketIntervals(
        for interval: DateInterval,
        grouping: UsageTrendGrouping,
        calendar: Calendar
    ) -> [DateInterval] {
        let component: Calendar.Component
        switch grouping {
        case .day:
            component = .day
        case .week:
            component = .weekOfYear
        case .month:
            component = .month
        }

        var buckets: [DateInterval] = []
        var cursor = calendar.dateInterval(of: component, for: interval.start)?.start ?? interval.start
        while cursor < interval.end {
            guard let next = calendar.date(byAdding: component, value: 1, to: cursor) else { break }
            let start = max(cursor, interval.start)
            let end = min(next, interval.end)
            if end > start {
                buckets.append(DateInterval(start: start, end: end))
            }
            cursor = next
        }
        return buckets
    }

    private static func dayTotals(from slices: [UsageAnalyticsSlice], calendar: Calendar) -> [Date: TimeInterval] {
        var totals: [Date: TimeInterval] = [:]
        for slice in slices {
            var cursor = calendar.startOfDay(for: slice.startedAt)
            while cursor < slice.endedAt {
                guard let nextDay = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
                let dayInterval = DateInterval(start: cursor, end: nextDay)
                let seconds = overlapSeconds(sliceStart: slice.startedAt, sliceEnd: slice.endedAt, interval: dayInterval)
                if seconds > 0 {
                    totals[cursor, default: 0] += seconds
                }
                cursor = nextDay
            }
        }
        return totals
    }

    private static func representedDayCount(in interval: DateInterval, calendar: Calendar) -> Int {
        let start = calendar.startOfDay(for: interval.start)
        let end = calendar.startOfDay(for: interval.end)
        let days = calendar.dateComponents([.day], from: start, to: end).day ?? 0
        return max(1, days + 1)
    }

    private static func overlapSeconds(sliceStart: Date, sliceEnd: Date, interval: DateInterval) -> TimeInterval {
        let start = max(sliceStart, interval.start)
        let end = min(sliceEnd, interval.end)
        return max(0, end.timeIntervalSince(start))
    }

    private static func unusedStoragePassPercentChange(current: Double, previous: Double) -> Double? {
        guard previous > 0 else { return nil }
        return (current - previous) / previous
    }

    private func fetchOverlappingSegments(start: Date, end: Date) throws -> [UsageSegment] {
        try queue.sync {
            try database.query(
                """
                SELECT * FROM usage_segments
                WHERE ended_at > ? AND started_at < ?
                ORDER BY started_at
                """,
                [.double(start.timeIntervalSince1970), .double(end.timeIntervalSince1970)]
            ).compactMap(Self.segment(from:))
        }
    }

    private func storageTotals() throws -> [String: StorageTotals] {
        try queue.sync {
            let items = try database.query("SELECT * FROM storage_items").compactMap(Self.storageItem(from:))
            var totals: [String: StorageTotals] = [:]

            for item in items {
                var total = totals[item.appID] ?? StorageTotals()
                if item.category == .bundle {
                    total.bundleSizeBytes += item.sizeBytes
                } else {
                    total.relatedSizeBytes += item.sizeBytes
                }
                if item.warning != nil {
                    total.warningCount += 1
                }
                total.scannedAt = max(total.scannedAt ?? .distantPast, item.scannedAt)
                totals[item.appID] = total
            }

            return totals
        }
    }

    private func importedUsageTotals(start: Date, end: Date, calendar: Calendar) throws -> [String: ImportedUsageTotals] {
        let dayStart = calendar.startOfDay(for: start)
        let dayEnd = calendar.startOfDay(for: end)

        return try queue.sync {
            var totals: [String: ImportedUsageTotals] = [:]

            for row in try database.query("SELECT * FROM imported_usage_history") {
                guard let appID = row["app_id"]?.string else { continue }
                totals[appID] = ImportedUsageTotals(
                    lastUsed: row["last_used"]?.double.map { Date(timeIntervalSince1970: $0) },
                    useCount: row["use_count"]?.int64,
                    daysInPeriod: 0,
                    importedAt: row["imported_at"]?.double.map { Date(timeIntervalSince1970: $0) }
                )
            }

            let dayRows = try database.query(
                """
                SELECT app_id, COUNT(*) AS used_days
                FROM imported_usage_days
                WHERE day_start >= ? AND day_start <= ?
                GROUP BY app_id
                """,
                [.double(dayStart.timeIntervalSince1970), .double(dayEnd.timeIntervalSince1970)]
            )

            for row in dayRows {
                guard let appID = row["app_id"]?.string else { continue }
                var total = totals[appID] ?? ImportedUsageTotals()
                total.daysInPeriod = Int(row["used_days"]?.int64 ?? 0)
                totals[appID] = total
            }

            return totals
        }
    }

    private func analyticsAllowedAppIDs(
        includeAll: Bool,
        includedAppIDs: Set<String>?,
        excludedAppIDs: Set<String>
    ) throws -> Set<String> {
        var allowed = Set(try fetchApps(includeAll: includeAll).map(\.id))
        if let includedAppIDs {
            allowed = allowed.intersection(includedAppIDs)
        }
        allowed.subtract(excludedAppIDs)
        return allowed
    }

    private func usageSlices(start: Date, end: Date, allowedAppIDs: Set<String>) throws -> [UsageSlice] {
        guard !allowedAppIDs.isEmpty else { return [] }

        return try fetchOverlappingSegments(start: start, end: end).compactMap { segment in
            guard allowedAppIDs.contains(segment.appID) else { return nil }
            let clippedStart = max(segment.startedAt, start)
            let clippedEnd = min(segment.endedAt, end)
            let seconds = clippedEnd.timeIntervalSince(clippedStart)
            guard seconds >= 1 else { return nil }

            return UsageSlice(
                sourceID: segment.id,
                appID: segment.appID,
                appName: segment.appName,
                appPath: segment.appPath,
                startedAt: clippedStart,
                endedAt: clippedEnd
            )
        }
    }

    private static func analyticsSummary(
        currentSlices: [UsageSlice],
        previousSlices: [UsageSlice],
        interval: DateInterval,
        previousInterval: DateInterval,
        topApps: [TopAppUsage],
        calendar: Calendar
    ) -> UsageAnalyticsSummary {
        let totalSeconds = currentSlices.reduce(0) { $0 + $1.seconds }
        let previousTotalSeconds = previousSlices.reduce(0) { $0 + $1.seconds }
        let dayTotals = usageByDay(from: currentSlices, calendar: calendar)
        let activeDays = max(1, dayCount(in: interval, calendar: calendar))
        let previousActiveDays = max(1, dayCount(in: previousInterval, calendar: calendar))
        let dailyAverageSeconds = totalSeconds / Double(activeDays)
        let previousDailyAverageSeconds = previousTotalSeconds / Double(previousActiveDays)
        let peak = dayTotals.max { lhs, rhs in
            if lhs.value == rhs.value { return lhs.key > rhs.key }
            return lhs.value < rhs.value
        }
        let previousSessionCount = previousSlices.count
        let comparison = UsagePeriodComparison(
            previousTotalSeconds: previousTotalSeconds,
            totalDeltaSeconds: totalSeconds - previousTotalSeconds,
            totalPercentChange: percentChange(current: totalSeconds, previous: previousTotalSeconds),
            previousDailyAverageSeconds: previousDailyAverageSeconds,
            dailyAverageDeltaSeconds: dailyAverageSeconds - previousDailyAverageSeconds,
            dailyAveragePercentChange: percentChange(current: dailyAverageSeconds, previous: previousDailyAverageSeconds),
            previousSessionCount: previousSessionCount,
            sessionDelta: currentSlices.count - previousSessionCount,
            sessionPercentChange: percentChange(current: Double(currentSlices.count), previous: Double(previousSessionCount))
        )

        return UsageAnalyticsSummary(
            totalSeconds: totalSeconds,
            dailyAverageSeconds: dailyAverageSeconds,
            peakDay: peak?.key,
            peakDaySeconds: peak?.value ?? 0,
            mostUsedApp: topApps.first,
            sessionCount: currentSlices.count,
            comparison: comparison
        )
    }

    private static func topApps(from slices: [UsageSlice]) -> [TopAppUsage] {
        var accumulators: [String: AppUsageAccumulator] = [:]
        for slice in slices {
            var accumulator = accumulators[slice.appID] ?? AppUsageAccumulator(
                appName: slice.appName,
                appPath: slice.appPath
            )
            accumulator.seconds += slice.seconds
            accumulator.sessionCount += 1
            accumulators[slice.appID] = accumulator
        }

        let total = max(slices.reduce(0) { $0 + $1.seconds }, 1)
        return accumulators.map { appID, accumulator in
            TopAppUsage(
                appID: appID,
                appName: accumulator.appName,
                appPath: accumulator.appPath,
                seconds: accumulator.seconds,
                percentOfTotal: accumulator.seconds / total
            )
        }
        .sorted { lhs, rhs in
            if lhs.seconds == rhs.seconds {
                return lhs.appName.localizedCaseInsensitiveCompare(rhs.appName) == .orderedAscending
            }
            return lhs.seconds > rhs.seconds
        }
    }

    private static func trendBuckets(
        from slices: [UsageSlice],
        interval: DateInterval,
        grouping: UsageTrendGrouping,
        visibleTopAppIDs: [String],
        topApps: [TopAppUsage],
        calendar: Calendar
    ) -> [UsageTrendBucket] {
        let bucketFrames = bucketFrames(for: interval, grouping: grouping, calendar: calendar)
        guard !bucketFrames.isEmpty else { return [] }

        let topAppIDSet = Set(visibleTopAppIDs)
        let topAppsByID = Dictionary(uniqueKeysWithValues: topApps.map { ($0.appID, $0) })
        var totalsByBucket: [String: [String: TimeInterval]] = [:]

        for slice in slices {
            splitByBuckets(slice: slice, grouping: grouping, calendar: calendar) { bucketStart, sliceStart, sliceEnd in
                let seconds = sliceEnd.timeIntervalSince(sliceStart)
                guard seconds > 0 else { return }
                let bucketID = bucketIdentifier(for: bucketStart)
                let stackID = topAppIDSet.contains(slice.appID) ? slice.appID : otherAppID
                totalsByBucket[bucketID, default: [:]][stackID, default: 0] += seconds
            }
        }

        return bucketFrames.map { frame in
            let bucketID = bucketIdentifier(for: frame.start)
            let totals = totalsByBucket[bucketID] ?? [:]
            let totalSeconds = totals.values.reduce(0, +)
            var stacks: [UsageStackSegment] = []

            for appID in visibleTopAppIDs {
                guard let seconds = totals[appID], seconds > 0, let app = topAppsByID[appID] else { continue }
                stacks.append(UsageStackSegment(
                    id: "\(bucketID)|\(appID)",
                    appID: appID,
                    appName: app.appName,
                    appPath: app.appPath,
                    seconds: seconds,
                    percentOfBucket: totalSeconds > 0 ? seconds / totalSeconds : 0
                ))
            }

            if let otherSeconds = totals[otherAppID], otherSeconds > 0 {
                stacks.append(UsageStackSegment(
                    id: "\(bucketID)|\(otherAppID)",
                    appID: otherAppID,
                    appName: "Other",
                    appPath: "",
                    seconds: otherSeconds,
                    percentOfBucket: totalSeconds > 0 ? otherSeconds / totalSeconds : 0,
                    isOther: true
                ))
            }

            return UsageTrendBucket(
                id: bucketID,
                start: frame.start,
                end: frame.end,
                stacks: stacks,
                totalSeconds: totalSeconds
            )
        }
    }

    private static func heatmapCells(
        from slices: [UsageSlice],
        period: ReportingPeriod,
        interval: DateInterval,
        calendar: Calendar
    ) -> [UsageHeatmapCell] {
        let rows = heatmapRows(period: period, interval: interval, calendar: calendar)
        guard !rows.isEmpty else { return [] }

        let rowByKey = Dictionary(uniqueKeysWithValues: rows.map { ($0.key, $0) })
        var cells: [String: HeatmapAccumulator] = [:]
        for row in rows {
            for hour in 0..<24 {
                cells[heatmapCellID(rowKey: row.key, hour: hour)] = HeatmapAccumulator()
            }
        }

        for slice in slices {
            splitByCalendarComponent(start: slice.startedAt, end: slice.endedAt, component: .hour, calendar: calendar) { sliceStart, sliceEnd in
                let hourStart = calendar.dateInterval(of: .hour, for: sliceStart)?.start ?? sliceStart
                let rowKey: String
                if period == .year {
                    rowKey = "weekday-\(calendar.component(.weekday, from: hourStart))"
                } else {
                    rowKey = "day-\(Int(calendar.startOfDay(for: hourStart).timeIntervalSince1970))"
                }
                guard rowByKey[rowKey] != nil else { return }

                let hour = calendar.component(.hour, from: hourStart)
                let cellID = heatmapCellID(rowKey: rowKey, hour: hour)
                let seconds = sliceEnd.timeIntervalSince(sliceStart)
                guard seconds > 0 else { return }

                var accumulator = cells[cellID] ?? HeatmapAccumulator()
                accumulator.seconds += seconds
                accumulator.sessionCount += 1
                accumulator.secondsByApp[slice.appID, default: 0] += seconds
                accumulator.appNamesByID[slice.appID] = slice.appName
                cells[cellID] = accumulator
            }
        }

        return rows.flatMap { row in
            (0..<24).map { hour in
                let id = heatmapCellID(rowKey: row.key, hour: hour)
                let accumulator = cells[id] ?? HeatmapAccumulator()
                let topApp = accumulator.secondsByApp.max { lhs, rhs in
                    if lhs.value == rhs.value { return lhs.key > rhs.key }
                    return lhs.value < rhs.value
                }
                return UsageHeatmapCell(
                    id: id,
                    rowStart: row.rowStart,
                    rowLabel: row.label,
                    hourOfDay: hour,
                    seconds: accumulator.seconds,
                    sessionCount: accumulator.sessionCount,
                    topAppID: topApp?.key,
                    topAppName: topApp.flatMap { accumulator.appNamesByID[$0.key] }
                )
            }
        }
    }

    private static func usageByDay(from slices: [UsageSlice], calendar: Calendar) -> [Date: TimeInterval] {
        var totals: [Date: TimeInterval] = [:]
        for slice in slices {
            splitByCalendarComponent(start: slice.startedAt, end: slice.endedAt, component: .day, calendar: calendar) { start, end in
                let day = calendar.startOfDay(for: start)
                totals[day, default: 0] += end.timeIntervalSince(start)
            }
        }
        return totals
    }

    private static func bucketFrames(
        for interval: DateInterval,
        grouping: UsageTrendGrouping,
        calendar: Calendar
    ) -> [(start: Date, end: Date)] {
        var frames: [(Date, Date)] = []
        var cursor = bucketStart(for: interval.start, grouping: grouping, calendar: calendar)

        while cursor < interval.end {
            guard let next = nextBucketStart(after: cursor, grouping: grouping, calendar: calendar) else { break }
            frames.append((cursor, min(next, interval.end)))
            cursor = next
        }

        return frames
    }

    private static func splitByBuckets(
        slice: UsageSlice,
        grouping: UsageTrendGrouping,
        calendar: Calendar,
        body: (Date, Date, Date) -> Void
    ) {
        var cursor = slice.startedAt
        while cursor < slice.endedAt {
            let bucketStart = bucketStart(for: cursor, grouping: grouping, calendar: calendar)
            guard let bucketEnd = nextBucketStart(after: bucketStart, grouping: grouping, calendar: calendar) else { break }
            let sliceEnd = min(slice.endedAt, bucketEnd)
            if sliceEnd > cursor {
                body(bucketStart, cursor, sliceEnd)
            }
            guard sliceEnd > cursor else { break }
            cursor = sliceEnd
        }
    }

    private static func splitByCalendarComponent(
        start: Date,
        end: Date,
        component: Calendar.Component,
        calendar: Calendar,
        body: (Date, Date) -> Void
    ) {
        var cursor = start
        while cursor < end {
            let componentEnd = calendar.dateInterval(of: component, for: cursor)?.end
                ?? calendar.date(byAdding: component, value: 1, to: cursor)
                ?? end
            let sliceEnd = min(end, componentEnd)
            if sliceEnd > cursor {
                body(cursor, sliceEnd)
            }
            guard sliceEnd > cursor else { break }
            cursor = sliceEnd
        }
    }

    private static func bucketStart(
        for date: Date,
        grouping: UsageTrendGrouping,
        calendar: Calendar
    ) -> Date {
        calendar.dateInterval(of: grouping.calendarComponent, for: date)?.start
            ?? calendar.startOfDay(for: date)
    }

    private static func nextBucketStart(
        after date: Date,
        grouping: UsageTrendGrouping,
        calendar: Calendar
    ) -> Date? {
        calendar.date(byAdding: grouping.calendarComponent, value: 1, to: date)
    }

    private static func heatmapRows(
        period: ReportingPeriod,
        interval: DateInterval,
        calendar: Calendar
    ) -> [HeatmapRow] {
        if period == .year {
            let formatter = DateFormatter()
            formatter.calendar = calendar
            formatter.timeZone = calendar.timeZone
            let symbols = formatter.shortWeekdaySymbols ?? ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
            let weekdayOrder = (0..<7).map { ((calendar.firstWeekday - 1 + $0) % 7) + 1 }
            let anchor = calendar.startOfDay(for: interval.start)
            return weekdayOrder.enumerated().compactMap { index, weekday in
                guard let rowStart = calendar.date(byAdding: .day, value: index, to: anchor) else { return nil }
                return HeatmapRow(
                    key: "weekday-\(weekday)",
                    rowStart: rowStart,
                    label: symbols[weekday - 1]
                )
            }
        }

        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.setLocalizedDateFormatFromTemplate("MMM d")

        var rows: [HeatmapRow] = []
        var cursor = calendar.startOfDay(for: interval.start)
        while cursor < interval.end {
            rows.append(HeatmapRow(
                key: "day-\(Int(cursor.timeIntervalSince1970))",
                rowStart: cursor,
                label: formatter.string(from: cursor)
            ))
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor), next > cursor else { break }
            cursor = next
        }
        return rows
    }

    private static func dayCount(in interval: DateInterval, calendar: Calendar) -> Int {
        let start = calendar.startOfDay(for: interval.start)
        let end = calendar.startOfDay(for: interval.end)
        let days = calendar.dateComponents([.day], from: start, to: end).day ?? 0
        return max(1, days + 1)
    }

    private static func previousEquivalentInterval(for interval: DateInterval) -> DateInterval {
        let duration = max(interval.duration, 1)
        let start = interval.start.addingTimeInterval(-duration)
        return DateInterval(start: start, end: interval.start)
    }

    private static func percentChange(current: Double, previous: Double) -> Double? {
        guard previous > 0 else { return nil }
        return (current - previous) / previous
    }

    private static func bucketIdentifier(for date: Date) -> String {
        String(Int(date.timeIntervalSince1970))
    }

    private static func heatmapCellID(rowKey: String, hour: Int) -> String {
        "\(rowKey)|\(hour)"
    }

    private func insertHealthFinding(_ finding: AppHealthFinding) throws {
        try database.execute(
            """
            INSERT INTO health_findings
            (id, app_id, severity, title, detail, source, checked_at)
            VALUES (?, ?, ?, ?, ?, ?, ?)
            """,
            [
                .text(finding.id),
                .text(finding.appID),
                .text(finding.severity.rawValue),
                .text(finding.title),
                .text(finding.detail),
                .text(finding.source),
                .double(finding.checkedAt.timeIntervalSince1970)
            ]
        )
    }

    private func upsertCleanupSuggestion(_ suggestion: CleanupSuggestion) throws {
        try database.execute(
            """
            INSERT INTO cleanup_suggestions
            (id, app_id, title, path, category, size_bytes, severity, rationale, risk_notes, state, quarantine_path, created_at, updated_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(id) DO UPDATE SET
                title = excluded.title,
                path = excluded.path,
                category = excluded.category,
                size_bytes = excluded.size_bytes,
                severity = excluded.severity,
                rationale = excluded.rationale,
                risk_notes = excluded.risk_notes,
                state = excluded.state,
                quarantine_path = excluded.quarantine_path,
                updated_at = excluded.updated_at
            """,
            [
                .text(suggestion.id),
                .text(suggestion.appID),
                .text(suggestion.title),
                .text(suggestion.path),
                .text(suggestion.category.rawValue),
                .int64(suggestion.sizeBytes),
                .text(suggestion.severity.rawValue),
                .text(suggestion.rationale),
                .text(suggestion.riskNotes),
                .text(suggestion.state.rawValue),
                suggestion.quarantinePath.map(SQLiteValue.text) ?? .null,
                .double(suggestion.createdAt.timeIntervalSince1970),
                .double(suggestion.updatedAt.timeIntervalSince1970)
            ]
        )
    }

    private func insertUninstallRun(_ run: UninstallRunRecord) throws {
        try database.execute(
            """
            INSERT INTO uninstall_runs
            (id, app_id, app_name, app_path, bundle_id, status, started_at, completed_at, selected_item_count, trashed_item_count, failed_item_count, skipped_item_count, selected_bytes, message)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            [
                .text(run.id),
                .text(run.appID),
                .text(run.appName),
                .text(run.appPath),
                run.bundleIdentifier.map(SQLiteValue.text) ?? .null,
                .text(run.status.rawValue),
                .double(run.startedAt.timeIntervalSince1970),
                .double(run.completedAt.timeIntervalSince1970),
                .int64(Int64(run.selectedItemCount)),
                .int64(Int64(run.trashedItemCount)),
                .int64(Int64(run.failedItemCount)),
                .int64(Int64(run.skippedItemCount)),
                .int64(run.selectedBytes),
                run.message.map(SQLiteValue.text) ?? .null
            ]
        )
    }

    private func insertUninstallItemResult(_ result: UninstallItemResult) throws {
        try database.execute(
            """
            INSERT INTO uninstall_item_results
            (id, run_id, item_id, app_id, path, category, role, size_bytes, risk, status, message, completed_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            [
                .text(result.id),
                .text(result.runID),
                .text(result.itemID),
                .text(result.appID),
                .text(result.path),
                .text(result.category.rawValue),
                .text(result.role.rawValue),
                .int64(result.sizeBytes),
                .text(result.risk.rawValue),
                .text(result.status.rawValue),
                result.message.map(SQLiteValue.text) ?? .null,
                .double(result.completedAt.timeIntervalSince1970)
            ]
        )
    }

    private func insertAppUpdate(_ record: AppUpdateRecord) throws {
        try database.execute(
            """
            INSERT INTO app_updates
            (id, app_id, app_name, bundle_id, app_path, source, source_identifier, current_version, available_version, status, checked_at, install_action_title, install_action_url, requires_admin, requires_restart, can_install, is_auto_eligible, release_notes_title, release_notes_summary, release_notes_url, message)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            [
                .text(record.id),
                record.appID.map(SQLiteValue.text) ?? .null,
                .text(record.appName),
                record.bundleIdentifier.map(SQLiteValue.text) ?? .null,
                record.appPath.map(SQLiteValue.text) ?? .null,
                .text(record.source.rawValue),
                .text(record.sourceIdentifier),
                record.currentVersion.map(SQLiteValue.text) ?? .null,
                record.availableVersion.map(SQLiteValue.text) ?? .null,
                .text(record.status.rawValue),
                .double(record.checkedAt.timeIntervalSince1970),
                .text(record.installActionTitle),
                record.installActionURL.map(SQLiteValue.text) ?? .null,
                .int64(record.requiresAdmin ? 1 : 0),
                .int64(record.requiresRestart ? 1 : 0),
                .int64(record.canInstall ? 1 : 0),
                .int64(record.isAutoEligible ? 1 : 0),
                record.releaseNotesTitle.map(SQLiteValue.text) ?? .null,
                record.releaseNotesSummary.map(SQLiteValue.text) ?? .null,
                record.releaseNotesURL.map(SQLiteValue.text) ?? .null,
                record.message.map(SQLiteValue.text) ?? .null
            ]
        )
    }

    private func upsertChangeLogEntry(_ entry: AppChangeLogEntry) throws {
        try database.execute(
            """
            INSERT INTO app_changelogs
            (id, app_id, app_name, bundle_id, app_path, source, source_identifier, from_version, to_version, title, summary, release_notes_url, update_run_id, update_result_id, captured_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(id) DO UPDATE SET
                app_name = excluded.app_name,
                bundle_id = excluded.bundle_id,
                app_path = excluded.app_path,
                title = excluded.title,
                summary = excluded.summary,
                release_notes_url = excluded.release_notes_url,
                update_run_id = excluded.update_run_id,
                update_result_id = excluded.update_result_id,
                captured_at = excluded.captured_at
            """,
            [
                .text(entry.id),
                entry.appID.map(SQLiteValue.text) ?? .null,
                .text(entry.appName),
                entry.bundleIdentifier.map(SQLiteValue.text) ?? .null,
                entry.appPath.map(SQLiteValue.text) ?? .null,
                .text(entry.source.rawValue),
                .text(entry.sourceIdentifier),
                entry.fromVersion.map(SQLiteValue.text) ?? .null,
                entry.toVersion.map(SQLiteValue.text) ?? .null,
                .text(entry.title),
                .text(entry.summary),
                entry.releaseNotesURL.map(SQLiteValue.text) ?? .null,
                entry.updateRunID.map(SQLiteValue.text) ?? .null,
                entry.updateResultID.map(SQLiteValue.text) ?? .null,
                .double(entry.capturedAt.timeIntervalSince1970)
            ]
        )
    }

    private func insertUpdateRun(_ run: UpdateRunRecord) throws {
        try database.execute(
            """
            INSERT INTO update_runs
            (id, mode, status, started_at, completed_at, selected_item_count, updated_item_count, failed_item_count, skipped_item_count, message)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            [
                .text(run.id),
                .text(run.mode.rawValue),
                .text(run.status.rawValue),
                .double(run.startedAt.timeIntervalSince1970),
                .double(run.completedAt.timeIntervalSince1970),
                .int64(Int64(run.selectedItemCount)),
                .int64(Int64(run.updatedItemCount)),
                .int64(Int64(run.failedItemCount)),
                .int64(Int64(run.skippedItemCount)),
                run.message.map(SQLiteValue.text) ?? .null
            ]
        )
    }

    private func insertUpdateItemResult(_ result: UpdateItemResult) throws {
        try database.execute(
            """
            INSERT INTO update_item_results
            (id, run_id, update_id, app_id, app_name, source, source_identifier, status, message, completed_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            [
                .text(result.id),
                .text(result.runID),
                .text(result.updateID),
                result.appID.map(SQLiteValue.text) ?? .null,
                .text(result.appName),
                .text(result.source.rawValue),
                .text(result.sourceIdentifier),
                .text(result.status.rawValue),
                result.message.map(SQLiteValue.text) ?? .null,
                .double(result.completedAt.timeIntervalSince1970)
            ]
        )
    }

    private func upsertLargeFile(_ record: LargeFileRecord) throws {
        try database.execute(
            """
            INSERT INTO large_files
            (id, app_id, path, category, size_bytes, risk_score, risk_reason, modified_at, state, scanned_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(id) DO UPDATE SET
                path = excluded.path,
                category = excluded.category,
                size_bytes = excluded.size_bytes,
                risk_score = excluded.risk_score,
                risk_reason = excluded.risk_reason,
                modified_at = excluded.modified_at,
                state = excluded.state,
                scanned_at = excluded.scanned_at
            """,
            [
                .text(record.id),
                .text(record.appID),
                .text(record.path),
                .text(record.category.rawValue),
                .int64(record.sizeBytes),
                .int64(Int64(record.riskScore)),
                .text(record.riskReason),
                record.modifiedAt.map { .double($0.timeIntervalSince1970) } ?? .null,
                .text(record.state.rawValue),
                .double(record.scannedAt.timeIntervalSince1970)
            ]
        )
    }

    private static func app(from row: [String: SQLiteValue]) -> MonitoredApp? {
        guard
            let id = row["id"]?.string,
            let name = row["name"]?.string,
            let path = row["path"]?.string,
            let isUserFacing = row["is_user_facing"]?.int64,
            let lastSeen = row["last_seen"]?.double
        else {
            return nil
        }

        return MonitoredApp(
            id: id,
            name: name,
            bundleIdentifier: row["bundle_id"]?.string,
            version: row["version"]?.string,
            path: path,
            isUserFacing: isUserFacing == 1,
            installedAt: row["installed_at"]?.double.map { Date(timeIntervalSince1970: $0) },
            bundleCreatedAt: row["bundle_created_at"]?.double.map { Date(timeIntervalSince1970: $0) },
            lastSeen: Date(timeIntervalSince1970: lastSeen)
        )
    }

    private static func segment(from row: [String: SQLiteValue]) -> UsageSegment? {
        guard
            let id = row["id"]?.string,
            let appID = row["app_id"]?.string,
            let appName = row["app_name"]?.string,
            let appPath = row["app_path"]?.string,
            let startedAt = row["started_at"]?.double,
            let endedAt = row["ended_at"]?.double
        else {
            return nil
        }

        return UsageSegment(
            id: id,
            appID: appID,
            bundleIdentifier: row["bundle_id"]?.string,
            appName: appName,
            appPath: appPath,
            startedAt: Date(timeIntervalSince1970: startedAt),
            endedAt: Date(timeIntervalSince1970: endedAt)
        )
    }

    private static func storageItem(from row: [String: SQLiteValue]) -> StorageScanItem? {
        guard
            let id = row["id"]?.string,
            let appID = row["app_id"]?.string,
            let categoryRaw = row["category"]?.string,
            let category = StorageCategory(rawValue: categoryRaw),
            let path = row["path"]?.string,
            let sizeBytes = row["size_bytes"]?.int64,
            let scannedAt = row["scanned_at"]?.double
        else {
            return nil
        }

        return StorageScanItem(
            id: id,
            appID: appID,
            category: category,
            path: path,
            sizeBytes: sizeBytes,
            warning: row["warning"]?.string,
            scannedAt: Date(timeIntervalSince1970: scannedAt)
        )
    }

    private static func healthFinding(from row: [String: SQLiteValue]) -> AppHealthFinding? {
        guard
            let id = row["id"]?.string,
            let appID = row["app_id"]?.string,
            let severityRaw = row["severity"]?.string,
            let severity = AppHealthSeverity(rawValue: severityRaw),
            let title = row["title"]?.string,
            let detail = row["detail"]?.string,
            let source = row["source"]?.string,
            let checkedAt = row["checked_at"]?.double
        else {
            return nil
        }

        return AppHealthFinding(
            id: id,
            appID: appID,
            severity: severity,
            title: title,
            detail: detail,
            source: source,
            checkedAt: Date(timeIntervalSince1970: checkedAt)
        )
    }

    private static func cleanupSuggestion(from row: [String: SQLiteValue]) -> CleanupSuggestion? {
        guard
            let id = row["id"]?.string,
            let appID = row["app_id"]?.string,
            let title = row["title"]?.string,
            let path = row["path"]?.string,
            let categoryRaw = row["category"]?.string,
            let category = StorageCategory(rawValue: categoryRaw),
            let sizeBytes = row["size_bytes"]?.int64,
            let severityRaw = row["severity"]?.string,
            let severity = CleanupSeverity(rawValue: severityRaw),
            let rationale = row["rationale"]?.string,
            let riskNotes = row["risk_notes"]?.string,
            let stateRaw = row["state"]?.string,
            let state = CleanupSuggestionState(rawValue: stateRaw),
            let createdAt = row["created_at"]?.double,
            let updatedAt = row["updated_at"]?.double
        else {
            return nil
        }

        return CleanupSuggestion(
            id: id,
            appID: appID,
            title: title,
            path: path,
            category: category,
            sizeBytes: sizeBytes,
            severity: severity,
            rationale: rationale,
            riskNotes: riskNotes,
            state: state,
            quarantinePath: row["quarantine_path"]?.string,
            createdAt: Date(timeIntervalSince1970: createdAt),
            updatedAt: Date(timeIntervalSince1970: updatedAt)
        )
    }

    private static func uninstallRun(from row: [String: SQLiteValue]) -> UninstallRunRecord? {
        guard
            let id = row["id"]?.string,
            let appID = row["app_id"]?.string,
            let appName = row["app_name"]?.string,
            let appPath = row["app_path"]?.string,
            let statusRaw = row["status"]?.string,
            let status = UninstallRunStatus(rawValue: statusRaw),
            let startedAt = row["started_at"]?.double,
            let completedAt = row["completed_at"]?.double,
            let selectedItemCount = row["selected_item_count"]?.int64,
            let trashedItemCount = row["trashed_item_count"]?.int64,
            let failedItemCount = row["failed_item_count"]?.int64,
            let skippedItemCount = row["skipped_item_count"]?.int64,
            let selectedBytes = row["selected_bytes"]?.int64
        else {
            return nil
        }

        return UninstallRunRecord(
            id: id,
            appID: appID,
            appName: appName,
            appPath: appPath,
            bundleIdentifier: row["bundle_id"]?.string,
            status: status,
            startedAt: Date(timeIntervalSince1970: startedAt),
            completedAt: Date(timeIntervalSince1970: completedAt),
            selectedItemCount: Int(selectedItemCount),
            trashedItemCount: Int(trashedItemCount),
            failedItemCount: Int(failedItemCount),
            skippedItemCount: Int(skippedItemCount),
            selectedBytes: selectedBytes,
            message: row["message"]?.string
        )
    }

    private static func uninstallItemResult(from row: [String: SQLiteValue]) -> UninstallItemResult? {
        guard
            let id = row["id"]?.string,
            let runID = row["run_id"]?.string,
            let itemID = row["item_id"]?.string,
            let appID = row["app_id"]?.string,
            let path = row["path"]?.string,
            let categoryRaw = row["category"]?.string,
            let category = StorageCategory(rawValue: categoryRaw),
            let roleRaw = row["role"]?.string,
            let role = UninstallPlanItemRole(rawValue: roleRaw),
            let sizeBytes = row["size_bytes"]?.int64,
            let riskRaw = row["risk"]?.string,
            let risk = UninstallRiskLevel(rawValue: riskRaw),
            let statusRaw = row["status"]?.string,
            let status = UninstallItemResultStatus(rawValue: statusRaw),
            let completedAt = row["completed_at"]?.double
        else {
            return nil
        }

        return UninstallItemResult(
            id: id,
            runID: runID,
            itemID: itemID,
            appID: appID,
            path: path,
            category: category,
            role: role,
            sizeBytes: sizeBytes,
            risk: risk,
            status: status,
            message: row["message"]?.string,
            completedAt: Date(timeIntervalSince1970: completedAt)
        )
    }

    private static func appUpdate(from row: [String: SQLiteValue]) -> AppUpdateRecord? {
        guard
            let id = row["id"]?.string,
            let appName = row["app_name"]?.string,
            let sourceRaw = row["source"]?.string,
            let source = AppUpdateSource(rawValue: sourceRaw),
            let sourceIdentifier = row["source_identifier"]?.string,
            let statusRaw = row["status"]?.string,
            let status = AppUpdateStatus(rawValue: statusRaw),
            let checkedAt = row["checked_at"]?.double,
            let installActionTitle = row["install_action_title"]?.string,
            let requiresAdmin = row["requires_admin"]?.int64,
            let requiresRestart = row["requires_restart"]?.int64,
            let canInstall = row["can_install"]?.int64,
            let isAutoEligible = row["is_auto_eligible"]?.int64
        else {
            return nil
        }

        return AppUpdateRecord(
            id: id,
            appID: row["app_id"]?.string,
            appName: appName,
            bundleIdentifier: row["bundle_id"]?.string,
            appPath: row["app_path"]?.string,
            source: source,
            sourceIdentifier: sourceIdentifier,
            currentVersion: row["current_version"]?.string,
            availableVersion: row["available_version"]?.string,
            status: status,
            checkedAt: Date(timeIntervalSince1970: checkedAt),
            installActionTitle: installActionTitle,
            installActionURL: row["install_action_url"]?.string,
            requiresAdmin: requiresAdmin == 1,
            requiresRestart: requiresRestart == 1,
            canInstall: canInstall == 1,
            isAutoEligible: isAutoEligible == 1,
            releaseNotesTitle: row["release_notes_title"]?.string,
            releaseNotesSummary: row["release_notes_summary"]?.string,
            releaseNotesURL: row["release_notes_url"]?.string,
            message: row["message"]?.string
        )
    }

    private static func changeLogEntry(from row: [String: SQLiteValue]) -> AppChangeLogEntry? {
        guard
            let id = row["id"]?.string,
            let appName = row["app_name"]?.string,
            let sourceRaw = row["source"]?.string,
            let source = AppUpdateSource(rawValue: sourceRaw),
            let sourceIdentifier = row["source_identifier"]?.string,
            let title = row["title"]?.string,
            let summary = row["summary"]?.string,
            let capturedAt = row["captured_at"]?.double
        else {
            return nil
        }

        return AppChangeLogEntry(
            id: id,
            appID: row["app_id"]?.string,
            appName: appName,
            bundleIdentifier: row["bundle_id"]?.string,
            appPath: row["app_path"]?.string,
            source: source,
            sourceIdentifier: sourceIdentifier,
            fromVersion: row["from_version"]?.string,
            toVersion: row["to_version"]?.string,
            title: title,
            summary: summary,
            releaseNotesURL: row["release_notes_url"]?.string,
            updateRunID: row["update_run_id"]?.string,
            updateResultID: row["update_result_id"]?.string,
            capturedAt: Date(timeIntervalSince1970: capturedAt)
        )
    }

    private static func updateRun(from row: [String: SQLiteValue]) -> UpdateRunRecord? {
        guard
            let id = row["id"]?.string,
            let modeRaw = row["mode"]?.string,
            let mode = UpdateRunMode(rawValue: modeRaw),
            let statusRaw = row["status"]?.string,
            let status = UpdateRunStatus(rawValue: statusRaw),
            let startedAt = row["started_at"]?.double,
            let completedAt = row["completed_at"]?.double,
            let selectedItemCount = row["selected_item_count"]?.int64,
            let updatedItemCount = row["updated_item_count"]?.int64,
            let failedItemCount = row["failed_item_count"]?.int64,
            let skippedItemCount = row["skipped_item_count"]?.int64
        else {
            return nil
        }

        return UpdateRunRecord(
            id: id,
            mode: mode,
            status: status,
            startedAt: Date(timeIntervalSince1970: startedAt),
            completedAt: Date(timeIntervalSince1970: completedAt),
            selectedItemCount: Int(selectedItemCount),
            updatedItemCount: Int(updatedItemCount),
            failedItemCount: Int(failedItemCount),
            skippedItemCount: Int(skippedItemCount),
            message: row["message"]?.string
        )
    }

    private static func updateItemResult(from row: [String: SQLiteValue]) -> UpdateItemResult? {
        guard
            let id = row["id"]?.string,
            let runID = row["run_id"]?.string,
            let updateID = row["update_id"]?.string,
            let appName = row["app_name"]?.string,
            let sourceRaw = row["source"]?.string,
            let source = AppUpdateSource(rawValue: sourceRaw),
            let sourceIdentifier = row["source_identifier"]?.string,
            let statusRaw = row["status"]?.string,
            let status = AppUpdateStatus(rawValue: statusRaw),
            let completedAt = row["completed_at"]?.double
        else {
            return nil
        }

        return UpdateItemResult(
            id: id,
            runID: runID,
            updateID: updateID,
            appID: row["app_id"]?.string,
            appName: appName,
            source: source,
            sourceIdentifier: sourceIdentifier,
            status: status,
            message: row["message"]?.string,
            completedAt: Date(timeIntervalSince1970: completedAt)
        )
    }

    private static func largeFile(from row: [String: SQLiteValue]) -> LargeFileRecord? {
        guard
            let id = row["id"]?.string,
            let appID = row["app_id"]?.string,
            let path = row["path"]?.string,
            let categoryRaw = row["category"]?.string,
            let category = StorageCategory(rawValue: categoryRaw),
            let sizeBytes = row["size_bytes"]?.int64,
            let riskScore = row["risk_score"]?.int64,
            let riskReason = row["risk_reason"]?.string,
            let stateRaw = row["state"]?.string,
            let state = LargeFileReviewState(rawValue: stateRaw),
            let scannedAt = row["scanned_at"]?.double
        else {
            return nil
        }

        return LargeFileRecord(
            id: id,
            appID: appID,
            path: path,
            category: category,
            sizeBytes: sizeBytes,
            riskScore: Int(riskScore),
            riskReason: riskReason,
            modifiedAt: row["modified_at"]?.double.map(Date.init(timeIntervalSince1970:)),
            state: state,
            scannedAt: Date(timeIntervalSince1970: scannedAt)
        )
    }

}

private struct UsageAccumulator {
    var seconds: TimeInterval = 0
    var lastUsed: Date?
}

private struct UsageAnalyticsSlice {
    let appID: String
    let appName: String
    let appPath: String
    let startedAt: Date
    let endedAt: Date

    var seconds: TimeInterval {
        max(0, endedAt.timeIntervalSince(startedAt))
    }
}

private let otherAppID = "__other__"

private struct UsageSlice {
    let sourceID: String
    let appID: String
    let appName: String
    let appPath: String
    let startedAt: Date
    let endedAt: Date

    var seconds: TimeInterval {
        max(0, endedAt.timeIntervalSince(startedAt))
    }
}

private struct AppUsageAccumulator {
    var appName: String
    var appPath: String
    var seconds: TimeInterval = 0
    var sessionCount: Int = 0
}

private struct HeatmapAccumulator {
    var seconds: TimeInterval = 0
    var sessionCount: Int = 0
    var secondsByApp: [String: TimeInterval] = [:]
    var appNamesByID: [String: String] = [:]
}

private struct HeatmapRow {
    let key: String
    let rowStart: Date
    let label: String
}

private extension UsageTrendGrouping {
    var calendarComponent: Calendar.Component {
        switch self {
        case .day:
            return .day
        case .week:
            return .weekOfYear
        case .month:
            return .month
        }
    }
}
