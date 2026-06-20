import Observation
import SwiftUI

/// The app's navigation state, kept out of any single view so menu commands,
/// state restoration, and deep links can all drive it. Domain-agnostic: it
/// addresses content by opaque `UUID`, not by any feature type.
@MainActor
@Observable
final class AppRouter {
    /// The primary sidebar/list selection.
    var selection: UUID?
    /// Pushed detail routes on top of the selection.
    var path = NavigationPath()

    func select(_ id: UUID?) {
        selection = id
    }

    func reset() {
        selection = nil
        path = NavigationPath()
    }
}
