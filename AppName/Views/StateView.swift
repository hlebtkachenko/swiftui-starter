import SwiftUI

/// Renders a `ContentState` the same way everywhere: a spinner while loading, a
/// standard empty state, the caller's content when loaded, and an error with an
/// optional retry. Screens describe their data; they never re-implement these
/// four cases.
struct ContentStateView<Value: Equatable, Loaded: View>: View {
    let state: ContentState<Value>
    var emptyMessage: String = "Nothing here yet"
    var emptySymbol: String = "tray"
    var retry: (() -> Void)?
    @ViewBuilder let loaded: (Value) -> Loaded

    var body: some View {
        switch state {
        case .loading:
            ProgressView()
        case .empty:
            ContentUnavailableView(emptyMessage, systemImage: emptySymbol)
        case .loaded(let value):
            loaded(value)
        case .failed(let message):
            ContentUnavailableView {
                Label("Something went wrong", systemImage: "exclamationmark.triangle")
            } description: {
                Text(message)
            } actions: {
                if let retry {
                    Button("Try Again", action: retry)
                }
            }
        }
    }
}

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
