import Foundation

/// A reusable, domain-agnostic screen state. Any screen that loads data renders
/// one of these four cases through `ContentStateView`, so loading, empty, and
/// error handling are written once instead of per screen.
enum ContentState<Value: Equatable>: Equatable {
    case loading
    case empty
    case loaded(Value)
    case failed(message: String)
}
