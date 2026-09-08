//
//  CarterLogging.swift
//
//  A library must not print.
//

import Foundation

/// Where Carter's diagnostics go. Defaults to silence.
///
/// 1.x called `print` fourteen times and `dump(urlInformation)` on every
/// success — dumping the whole model, and the raw response body, into the
/// consuming app's logs on every link a user pasted. That is noise in an app
/// and a data-leak risk on a server. Carter now emits nothing unless a host
/// opts in.
public enum CarterLog {

    public enum Level: Int, Comparable, Sendable {
        case debug = 0, info = 1, error = 2
        public static func < (l: Level, r: Level) -> Bool { l.rawValue < r.rawValue }
    }

    /// Set once at startup to receive diagnostics. Nil (default) discards them.
    /// On a server, forward this to swift-log; in an app, to `os.Logger`.
    public nonisolated(unsafe) static var handler: (@Sendable (Level, String) -> Void)?

    static func debug(_ message: @autoclosure () -> String) { handler?(.debug, message()) }
    static func info(_ message: @autoclosure () -> String)  { handler?(.info, message()) }
    static func error(_ message: @autoclosure () -> String) { handler?(.error, message()) }
}
