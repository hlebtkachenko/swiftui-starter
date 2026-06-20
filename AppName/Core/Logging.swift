import OSLog

/// App-wide logging facade. One stable subsystem, a fixed set of categories, so
/// log output is filterable in Console and Instruments and stray `NSLog`/`print`
/// calls can be retired (ADR-0012). `Logger` is `Sendable`, so these are safe to
/// touch from any isolation.
enum Log {
    static let subsystem = "dev.hapd.appname"

    static let app = Logger(subsystem: subsystem, category: "app")
    static let persistence = Logger(subsystem: subsystem, category: "persistence")
    static let sync = Logger(subsystem: subsystem, category: "sync")
    static let connectivity = Logger(subsystem: subsystem, category: "connectivity")
}
