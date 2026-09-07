//
//  DateParsing.swift
//

import Foundation

/// Turning a publisher's date string into a `Date`.
///
/// The library does this once so every consumer does not carry its own list of
/// formats — and so a format that only one publisher uses is fixed in one place.
enum DateParsing {

    /// Timezone abbreviations that mean different things in different places.
    ///
    /// This is not pedantry. A publisher stamping
    /// `Fri, 04 Sep 2026 22:13:46 PST` may mean Pacific Standard Time (UTC−8)
    /// or Philippine Standard Time (UTC+8) — sixteen hours apart, enough to
    /// place an article on the wrong DAY. `DateFormatter` under `en_US_POSIX`
    /// silently picks Pacific.
    ///
    /// Carter cannot infer which is meant, so it does not guess: the caller
    /// supplies the zone via `CarterConfiguration.ambiguousTimeZone`, and
    /// without one these are read as UTC.
    static let ambiguousAbbreviations: Set<String> = [
        "PST",  // Pacific (UTC−8) vs Philippine (UTC+8)
        "CST",  // US Central (UTC−6) vs China (UTC+8) vs Cuba
        "IST",  // India (UTC+5:30) vs Israel (UTC+2) vs Irish (UTC+1)
        "BST",  // British Summer (UTC+1) vs Bangladesh (UTC+6)
        "AMT",  // Amazon (UTC−4) vs Armenia (UTC+4)
        "ECT",  // Ecuador (UTC−5) vs European Central (UTC+1)
    ]

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

    /// Formats that carry an explicit numeric offset — never ambiguous.
    private static let zonedFormats = [
        "yyyy-MM-dd'T'HH:mm:ssZZZZZ",
        "EEE, dd MMM yyyy HH:mm:ss Z",
    ]

    /// Formats with NO zone information. Interpreted in the supplied zone.
    private static let zonelessFormats = [
        "EEE, dd MMM yyyy HH:mm:ss",
        "yyyy-MM-dd'T'HH:mm:ss",
        "yyyy-MM-dd HH:mm:ss",
        "yyyy-MM-dd",
        "MMMM d, yyyy",
        "MMM d, yyyy",
        "dd/MM/yyyy",
    ]

    private static func formatter(_ format: String, zone: TimeZone) -> DateFormatter {
        let f = DateFormatter()
        // POSIX locale: a device set to another language must not parse a
        // publisher's month name differently.
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = zone
        f.dateFormat = format
        return f
    }

    /// - Parameter ambiguousZone: how to read an ambiguous abbreviation such as
    ///   `PST`, and any date carrying no zone at all. Defaults to UTC.
    static func date(from string: String, ambiguousZone: TimeZone? = nil) -> Date? {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let zone = ambiguousZone ?? TimeZone(secondsFromGMT: 0)!

        // 1. Unambiguous machine formats first.
        if let d = iso8601WithFractional.date(from: trimmed) { return d }
        if let d = iso8601.date(from: trimmed) { return d }

        // 2. Explicit numeric offsets — trustworthy as written.
        for format in zonedFormats {
            if let d = formatter(format, zone: zone).date(from: trimmed) { return d }
        }

        // 3. A trailing alphabetic abbreviation. If it is ambiguous, strip it
        //    and read the clock time in the caller's zone rather than letting
        //    Foundation silently pick a continent.
        if let abbreviation = trailingAbbreviation(of: trimmed) {
            let body = String(trimmed.dropLast(abbreviation.count))
                .trimmingCharacters(in: .whitespaces)
            let resolved: TimeZone
            if ambiguousAbbreviations.contains(abbreviation) {
                resolved = zone
                CarterLog.debug("Ambiguous timezone '\(abbreviation)' read as \(zone.identifier)")
            } else if let known = TimeZone(abbreviation: abbreviation) {
                resolved = known
            } else {
                resolved = zone
            }
            for format in zonelessFormats {
                if let d = formatter(format, zone: resolved).date(from: body) { return d }
            }
        }

        // 4. No zone at all.
        for format in zonelessFormats {
            if let d = formatter(format, zone: zone).date(from: trimmed) { return d }
        }

        CarterLog.debug("Unrecognised publish date format: \(trimmed)")
        return nil
    }

    private static func trailingAbbreviation(of string: String) -> String? {
        guard let last = string.split(separator: " ").last else { return nil }
        let candidate = String(last)
        guard candidate.count >= 2, candidate.count <= 5,
              candidate.allSatisfy({ $0.isLetter && $0.isUppercase })
        else { return nil }
        return candidate
    }
}
