#if os(iOS)
import Foundation
import MetricKit
import OSLog

/// Receives MetricKit metric and diagnostic payloads (ADR-0012). The system
/// delivers at most one batch per day covering launch time, hangs, disk, energy,
/// and crash/diagnostic reports. First-party only, no payload leaves the device;
/// for now they are logged so they show up in Console and can be exported later.
final class MetricsSubscriber: NSObject, MXMetricManagerSubscriber {
    static let shared = MetricsSubscriber()

    func startReceiving() {
        MXMetricManager.shared.add(self)
    }

    func didReceive(_ payloads: [MXMetricPayload]) {
        for payload in payloads {
            Log.app.info("MetricKit metric payload received (\(payload.dictionaryRepresentation().count) keys)")
        }
    }

    func didReceive(_ payloads: [MXDiagnosticPayload]) {
        Log.app.error("MetricKit delivered \(payloads.count) diagnostic payload(s)")
    }
}
#endif
