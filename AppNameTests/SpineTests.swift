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
        let id = UUID()
        monitor.ingest(CloudSyncEvent(id: id, kind: .importData, inProgress: true))
        monitor.ingest(CloudSyncEvent(id: id, kind: .importData, inProgress: false))
        #expect(monitor.state == .idle)
        #expect(monitor.lastSync != nil)
    }

    @Test func concurrentPhasesStaySyncingUntilAllFinish() {
        let monitor = SyncMonitor()
        let setup = UUID()
        let export = UUID()
        monitor.ingest(CloudSyncEvent(id: setup, kind: .setup, inProgress: true))
        monitor.ingest(CloudSyncEvent(id: export, kind: .export, inProgress: true))
        monitor.ingest(CloudSyncEvent(id: setup, kind: .setup, inProgress: false))
        #expect(monitor.state == .syncing)
        monitor.ingest(CloudSyncEvent(id: export, kind: .export, inProgress: false))
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
        if case .error = monitor.state {} else { Issue.record("expected error state") }
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

    @Test(arguments: [
        (AccountState.available, true, SyncState.syncing, String?.none, SyncState.syncing),
        (.unknown, true, .idle, nil, .idle),
        (.noAccount, true, .syncing, nil, .accountUnavailable(reason: "Sign in to iCloud to sync")),
        (.available, false, .syncing, nil, .offline),
        (.noAccount, false, .idle, "disk full", .error(message: "disk full")),
    ])
    func displayStatePrecedence(
        account: AccountState, isOnline: Bool, sync: SyncState,
        storeError: String?, expected: SyncState
    ) {
        #expect(SyncState.display(account: account, isOnline: isOnline, sync: sync, storeError: storeError) == expected)
    }

    // MARK: Error persistence

    @Test func eventErrorSurvivesAnInProgressEvent() {
        let monitor = SyncMonitor()
        monitor.ingest(CloudSyncEvent(kind: .export, inProgress: false, errorDescription: "boom"))
        monitor.ingest(CloudSyncEvent(kind: .importData, inProgress: true))
        #expect(monitor.state == .error(message: "boom"))
    }

    @Test func twoEventsOfTheSameKindStaySyncingUntilBothFinish() {
        let monitor = SyncMonitor()
        let privateStore = UUID()
        let sharedStore = UUID()
        monitor.ingest(CloudSyncEvent(id: privateStore, kind: .importData, inProgress: true))
        monitor.ingest(CloudSyncEvent(id: sharedStore, kind: .importData, inProgress: true))
        monitor.ingest(CloudSyncEvent(id: privateStore, kind: .importData, inProgress: false))
        #expect(monitor.state == .syncing)
        monitor.ingest(CloudSyncEvent(id: sharedStore, kind: .importData, inProgress: false))
        #expect(monitor.state == .idle)
    }

    @Test func reportedErrorSurvivesACleanEventUntilDismissed() {
        let monitor = SyncMonitor()
        monitor.report(NSError(domain: "test", code: 2, userInfo: [NSLocalizedDescriptionKey: "accept failed"]))
        monitor.ingest(CloudSyncEvent(kind: .importData, inProgress: false))
        #expect(monitor.state == .error(message: "accept failed"))
        monitor.dismissReportedError()
        #expect(monitor.state == .idle)
    }

    @Test func storeLoadErrorPersistsThroughCleanEvents() {
        let monitor = SyncMonitor()
        monitor.report(storeLoadError: NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "load failed"]))
        monitor.ingest(CloudSyncEvent(kind: .importData, inProgress: false))
        #expect(monitor.state == .error(message: "load failed"))
    }
}
