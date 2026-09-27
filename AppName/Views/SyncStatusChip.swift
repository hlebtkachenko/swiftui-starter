import SwiftUI

/// A compact sync indicator for toolbars and chrome. Shows nothing when idle and
/// up to date; otherwise a symbol button that opens the state's full message, so
/// it works by tap and pointer alike. Plain styling for now; Liquid Glass
/// treatment comes with the design layer.
struct SyncStatusChip: View {
    let state: SyncState
    /// Called when the user closes the message, so a one-off error can be cleared.
    var onDismiss: () -> Void = {}
    @State private var showsMessage = false

    var body: some View {
        if let symbol {
            Button(state.label, systemImage: symbol) { showsMessage = true }
                .labelStyle(.iconOnly)
                .foregroundStyle(tint)
                .symbolEffect(.rotate, isActive: state == .syncing)
                .help(state.label)
                .popover(isPresented: $showsMessage) {
                    Text(state.label)
                        .padding()
                        .presentationCompactAdaptation(.popover)
                }
                .onChange(of: showsMessage) { _, isShown in
                    if !isShown { onDismiss() }
                }
        }
    }

    private var symbol: String? {
        switch state {
        case .idle: nil
        case .syncing: "arrow.triangle.2.circlepath"
        case .offline: "wifi.slash"
        case .accountUnavailable: "person.crop.circle.badge.exclamationmark"
        case .error: "exclamationmark.icloud"
        }
    }

    private var tint: Color {
        switch state {
        case .idle, .syncing: .primary
        case .offline: .secondary
        case .accountUnavailable: .orange
        case .error: .red
        }
    }
}

#Preview {
    HStack {
        SyncStatusChip(state: .syncing)
        SyncStatusChip(state: .offline)
        SyncStatusChip(state: .accountUnavailable(reason: "Sign in to iCloud to sync."))
        SyncStatusChip(state: .error(message: "Sync failed. Tap to retry."))
    }
    .padding()
}
