//
//  DateParsing.swift
//

import Foundation

/// Turning a publisher's date string into a `Date`.
///
/// The library does this once so every consumer does not carry its own list of
/// formats — and so a format that only one publisher uses is fixed in one place
/// rather than in each app that happened to hit it.
enum DateParsing {

    private static let iso8601WithFractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private static let iso8601: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    /// Formats seen in the wild that ISO8601DateFormatter will not take.
    /// POSIX locale and a fixed zone: a device in another locale must not parse
    /// a publisher's date differently.
    private static let fallbackFormats = [
        "yyyy-MM-dd'T'HH:mm:ssZZZZZ",
        "yyyy-MM-dd'T'HH:mm:ss",
        "yyyy-MM-dd HH:mm:ss",
        "yyyy-MM-dd",
        "EEE, dd MMM yyyy HH:mm:ss zzz",   // RFC 822 / RSS
        "EEE, dd MMM yyyy HH:mm:ss Z",
        "MMMM d, yyyy",
        "MMM d, yyyy",
        "dd/MM/yyyy",
    ]

    private static let fallbackFormatters: [DateFormatter] = fallbackFormats.map { format in
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(secondsFromGMT: 0)
        f.dateFormat = format
        return f
    }

    static func date(from string: String) -> Date? {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if let d = iso8601WithFractional.date(from: trimmed) { return d }
        if let d = iso8601.date(from: trimmed) { return d }
        for formatter in fallbackFormatters {
            if let d = formatter.date(from: trimmed) { return d }
        }
        CarterLog.debug("Unrecognised publish date format: \(trimmed)")
        return nil
    }
}
