//
//  CanonicalURL.swift
//
//  Turning many spellings of one article into one key.
//

import Foundation

/// Normalisation rules for deciding that two links are the same article.
///
/// This is the piece 1.x never had. `URLInformation.==` compared the raw `url`
/// of two in-memory objects, which is wrong in both directions: two different
/// articles that happen to share an `og:url` compared equal, while the same
/// article shared twice with different `utm_*` campaigns compared unequal.
/// Neither could see storage, so neither could answer "has this been posted?".
///
/// `dedupeKey` is the answer: a stable string to store on the row and put a
/// unique index on, so the DATABASE refuses the duplicate. A scraper cannot
/// enforce uniqueness — two people pasting the same link at the same moment
/// both pass any "check, then insert" written in application code.
public enum CanonicalURL {

    /// Query parameters that identify a CAMPAIGN, not a document. Two URLs
    /// differing only by these are the same article and must produce the same
    /// key. Kept deliberately narrow: dropping a parameter that DOES select
    /// content (`?id=`, `?p=`, `?story=`) would collapse distinct articles into
    /// one, which is far worse than missing a duplicate.
    public static let trackingParameters: Set<String> = [
        "utm_source", "utm_medium", "utm_campaign", "utm_term", "utm_content",
        "utm_id", "utm_name", "utm_reader", "utm_social", "utm_brand",
        "fbclid", "gclid", "dclid", "gclsrc", "wbraid", "gbraid",
        "msclkid", "twclid", "igshid", "igsh", "mibextid",
        "mc_cid", "mc_eid", "_hsenc", "_hsmi", "vero_id", "vero_conv",
        "oly_anon_id", "oly_enc_id", "s_cid", "ncid", "cmpid", "CMP",
        "spm", "scm", "ref_src", "ref_url", "share_id", "sh",
    ]

    /// Build the duplicate-detection key for a URL.
    ///
    /// Lowercases scheme and host, forces https (http and https serve one
    /// article, not two), drops `www.`, drops the default port, removes
    /// tracking parameters, sorts what remains so parameter ORDER cannot
    /// create a false distinct, drops the fragment (a `#section` is a position
    /// within one document), and trims a trailing slash except at the root.
    ///
    /// Returns nil only when there is no host to key on.
    public static func dedupeKey(for url: URL) -> String? {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: true),
              let rawHost = components.host, !rawHost.isEmpty
        else { return nil }

        var host = rawHost.lowercased()
        if host.hasPrefix("www.") { host.removeFirst(4) }
        // A trailing dot is the DNS root and is the same host.
        if host.hasSuffix(".") { host.removeLast() }

        components.scheme = "https"
        components.host = host
        components.port = nil
        components.fragment = nil
        components.user = nil
        components.password = nil

        if let items = components.queryItems {
            let kept = items
                .filter { !trackingParameters.contains($0.name) && !$0.name.lowercased().hasPrefix("utm_") }
                .sorted { ($0.name, $0.value ?? "") < ($1.name, $1.value ?? "") }
            components.queryItems = kept.isEmpty ? nil : kept
        }

        // A bare host has an EMPTY path; the same host with "/" has "/". They
        // are one document, so normalise to "/" before trimming — otherwise
        // https://site.com and https://site.com/ key differently, which is a
        // duplicate that slips straight through.
        var path = components.percentEncodedPath
        while path.count > 1 && path.hasSuffix("/") { path.removeLast() }
        if path.isEmpty { path = "/" }
        components.percentEncodedPath = path

        return components.url?.absoluteString ?? components.string
    }

    /// True when two URLs denote the same article.
    public static func isSameDocument(_ lhs: URL, _ rhs: URL) -> Bool {
        guard let a = dedupeKey(for: lhs), let b = dedupeKey(for: rhs) else { return false }
        return a == b
    }

    /// Whether a URL is safe to fetch or store.
    ///
    /// Only http/https. This is the guard 1.x lacked: it wrote a page's own
    /// `og:url` straight over the requested URL with a bare `URL(string:)`,
    /// so a page could hand back `javascript:` or `data:` and have it stored.
    public static func isFetchableWebURL(_ url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased() else { return false }
        guard scheme == "http" || scheme == "https" else { return false }
        return !(url.host?.isEmpty ?? true)
    }

    /// Registrable-ish host for allow-listing and display: lowercased, `www.`
    /// removed. NOT a public-suffix implementation — it will not fold
    /// `bbc.co.uk` subdomains — so treat it as a display and comparison aid.
    public static func normalizedHost(for url: URL) -> String? {
        guard var host = url.host?.lowercased(), !host.isEmpty else { return nil }
        if host.hasPrefix("www.") { host.removeFirst(4) }
        if host.hasSuffix(".") { host.removeLast() }
        return host
    }
}
