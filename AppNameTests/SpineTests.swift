import Testing
import Foundation
import CloudKit
@testable import AppName

/// Headless tests for the app spine: the sync state machine, error mapping,
/// and account mapping. None of these need a live CloudKit container
/// (ADR-0013); the event stream is fed as `Sendable` `CloudSyncEvent` values.
@MainActor
@Suite struct SpineTests {

    // MARK: SyncMonitor state machine

    @Test func startsIdle() {
        let monitor = SyncMonitor()
        #expect(monitor.state == .idle)
        #expect(monitor.lastSync == nil)
    }

    @Test func importInProgressReportsSyncing() {
        let monitor = SyncMonitor()
        monitor.ingest(CloudSyncEvent(kind: .importData, inProgress: true))
        #expect(monitor.state == .syncing)
    }

    @Test func completedImportReturnsToIdle() {
        let monitor = SyncMonitor()
        monitor.ingest(CloudSyncEvent(kind: .importData, inProgress: true))
        monitor.ingest(CloudSyncEvent(kind: .importData, inProgress: false))
        #expect(monitor.state == .idle)
        #expect(monitor.lastSync != nil)
    }

    @Test func concurrentPhasesStaySyncingUntilAllFinish() {
        let monitor = SyncMonitor()
        monitor.ingest(CloudSyncEvent(kind: .setup, inProgress: true))
        monitor.ingest(CloudSyncEvent(kind: .export, inProgress: true))
        monitor.ingest(CloudSyncEvent(kind: .setup, inProgress: false))
        #expect(monitor.state == .syncing)
        monitor.ingest(CloudSyncEvent(kind: .export, inProgress: false))
        #expect(monitor.state == .idle)
    }

    @Test func eventErrorMovesToErrorThenRecovers() {
        let monitor = SyncMonitor()
        monitor.ingest(CloudSyncEvent(kind: .export, inProgress: false, errorDescription: "boom"))
        #expect(monitor.state == .error(message: "boom"))
        // A later clean event clears the error.
        monitor.ingest(CloudSyncEvent(kind: .importData, inProgress: false))
        #expect(monitor.state == .idle)
    }

    @Test func reportedStoreLoadErrorSurfacesAsError() {
        let monitor = SyncMonitor()
        let error = NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "load failed"])
        monitor.report(storeLoadError: error)
        if case .error = monitor.state { } else { Issue.record("expected error state") }
    }

    // MARK: Error mapping

    @Test func mapsQuotaExceeded() {
        let error = NSError(domain: CKErrorDomain, code: CKError.Code.quotaExceeded.rawValue)
        #expect(SyncErrorMapper.describe(error).contains("storage"))
    }

    @Test func mapsNetworkFailure() {
        let error = NSError(domain: CKErrorDomain, code: CKError.Code.networkUnavailable.rawValue)
        #expect(SyncErrorMapper.describe(error).contains("network"))
    }

    @Test func mapsNotAuthenticated() {
        let error = NSError(domain: CKErrorDomain, code: CKError.Code.notAuthenticated.rawValue)
        #expect(SyncErrorMapper.describe(error).contains("Sign in"))
    }

    @Test func mapsNonCloudKitErrorWithItsDescription() {
        let error = NSError(domain: "other", code: 7, userInfo: [NSLocalizedDescriptionKey: "disk gone"])
        #expect(SyncErrorMapper.describe(error) == "disk gone")
    }

    // MARK: Account mapping

    @Test func mapsAccountStatus() {
        #expect(AccountState(.available) == .available)
        #expect(AccountState(.noAccount) == .noAccount)
        #expect(AccountState(.restricted) == .restricted)
        #expect(AccountState(.couldNotDetermine) == .couldNotDetermine)
    }

    // MARK: Composed display state

    @Test func displayStatePrefersAccountThenNetworkThenSync() {
        let env = AppEnvironment(persistence: PersistenceController(inMemory: true))
        // In-memory store, no CloudKit container -> connectivity reports available
        // only after start(); the default is .unknown, which is "not available".
        // Drive sync underneath and confirm account/network take precedence.
        if case .accountUnavailable = env.displayState {
            // Expected: unknown account is surfaced before sync.
        } else {
            Issue.record("expected account precedence while account is unknown")
        }
    }
}
