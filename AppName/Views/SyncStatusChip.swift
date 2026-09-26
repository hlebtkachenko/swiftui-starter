import SwiftUI

/// A compact sync indicator for toolbars and chrome. Shows nothing when idle and
/// up to date; otherwise a symbol plus the state's label. Plain styling for now;
/// Liquid Glass treatment comes with the design layer.
struct SyncStatusChip: View {
    let state: SyncState

    var body: some View {
        switch state {
        case .idle:
            EmptyView()
        case .syncing:
            Label("Syncing", systemImage: "arrow.triangle.2.circlepath")
                .labelStyle(.iconOnly)
                .symbolEffect(.rotate)
                .help(state.label)
        case .offline:
            Label(state.label, systemImage: "wifi.slash")
                .labelStyle(.iconOnly)
                .foregroundStyle(.secondary)
                .help(state.label)
        case .accountUnavailable:
            Label(state.label, systemImage: "person.crop.circle.badge.exclamationmark")
                .labelStyle(.iconOnly)
                .foregroundStyle(.orange)
                .help(state.label)
        case .error:
            Label(state.label, systemImage: "exclamationmark.icloud")
                .labelStyle(.iconOnly)
                .foregroundStyle(.red)
                .help(state.label)
        }
    }
}
