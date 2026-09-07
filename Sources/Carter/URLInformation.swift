//
//  URLInformation.swift
//
//  Created by Jayson Ng on 11/24/21.
//  based on Ocarina by Rens Verhoeven (MIT)
//

import Foundation
import Kanna

/// Everything Carter could learn about a link.
///
/// A value type as of 2.0. 1.x was a `class` whose fields were mutated during
/// parsing, so a caller holding one could watch it change underneath them.
public struct URLInformation: Equatable, Sendable {

    // MARK: - Identity

    /// The URL as the user gave it. Never rewritten.
    public let originalURL: URL

    /// Where the fetch actually ended up, after redirects.
    /// 1.x discarded this, so a whitelist only ever saw the pre-redirect host.
    public let finalURL: URL

    /// The best claim about this document's address: `<link rel="canonical">`
    /// if the page offers one and it passes the host check, else `og:url` under
    /// the same rule, else `finalURL`.
    ///
    /// A page's self-declared URL is a CLAIM, not a fact. 1.x wrote `og:url`
    /// straight over the requested URL with no validation at all, so a page on
    /// an allowed domain could make you store a link to anywhere. Carter now
    /// only accepts a claim that stays on the same registrable host; otherwise
    /// it keeps `finalURL` and records the rejection in `rejectedURLClaim`.
    public let canonicalURL: URL

    /// A self-declared canonical/og:url that was refused for pointing off-host.
    /// Surfaced rather than silently dropped: on a news site it is usually a
    /// CMS misconfiguration, but it is also exactly what a hostile page does.
    public let rejectedURLClaim: URL?

    /// The duplicate-detection key for `canonicalURL`.
    /// Store this and put a UNIQUE INDEX on it. See `CanonicalURL`.
    public let dedupeKey: String?

    /// `canonicalURL`'s host, lowercased and `www.`-stripped — the value to
    /// check against a publisher allow-list.
    public let host: String?

    /// Kept for source compatibility with 1.x. Same value as `canonicalURL`.
    @available(*, deprecated, renamed: "canonicalURL")
    public var url: URL { canonicalURL }

    // MARK: - Content

    public let type: URLInformationType
    public let siteName: String?
    public let title: String?
    public let author: String?
    public let descriptionText: String?
    public let keywords: String?
    public let imageURL: URL?
    public let imageSize: ImageSize?

    /// The publish date exactly as the page wrote it. Kept a `String` so
    /// existing call sites that parse it themselves keep working.
    public let publishDate: String?

    /// `publishDate` parsed. New in 2.0: the library does this once, correctly,
    /// instead of every consumer re-deriving it from a list of formats.
    public let publishedAt: Date?

    public let section: String?
    public let faviconURL: URL?
    public let appleTouchIconURL: URL?
    public let twitterCard: TwitterCardInformation?

    /// The HTTP status of the fetch, when there was one.
    public let statusCode: Int?

    /// Two links are equal when they are the same DOCUMENT.
    /// 1.x compared the og:url-mutated `url`, which made different articles
    /// sharing an og:url compare equal.
    public static func == (lhs: URLInformation, rhs: URLInformation) -> Bool {
        guard let l = lhs.dedupeKey, let r = rhs.dedupeKey else {
            return lhs.canonicalURL == rhs.canonicalURL
        }
        return l == r
    }
}

// MARK: - Parsing

extension URLInformation {

    /// Build from a fetched document.
    init(originalURL: URL,
         finalURL: URL,
         html: HTMLDocument?,
         mimeType: String?,
         statusCode: Int?,
         defaultType: URLInformationType,
         ambiguousTimeZone: TimeZone? = nil) {

        self.originalURL = originalURL
        self.finalURL = finalURL
        self.statusCode = statusCode

        guard let html else {
            // No HTML: all we can say is what the MIME type says.
            self.type = mimeType.map(URLInformationType.type(forMimeType:)) ?? defaultType
            self.canonicalURL = finalURL
            self.rejectedURLClaim = nil
            self.dedupeKey = CanonicalURL.dedupeKey(for: finalURL)
            self.host = CanonicalURL.normalizedHost(for: finalURL)
            self.siteName = nil; self.title = nil; self.author = nil
            self.descriptionText = nil; self.keywords = nil
            self.imageURL = nil; self.imageSize = nil
            self.publishDate = nil; self.publishedAt = nil
            self.section = nil; self.faviconURL = nil; self.appleTouchIconURL = nil
            self.twitterCard = nil
            return
        }

        let meta = MetaReader(html: html)

        // --- Address, decided BEFORE anything resolves against it -----------
        // Relative image/favicon URLs must resolve against a URL we trust.
        // 1.x reassigned `url` from og:url first, so every later
        // `relativeTo: url` inherited the page's claim.
        let claim = meta.url(forLinkRel: "canonical") ?? meta.url(forProperty: "og:url")
        if let claim, CanonicalURL.isFetchableWebURL(claim),
           CanonicalURL.normalizedHost(for: claim) == CanonicalURL.normalizedHost(for: finalURL) {
            self.canonicalURL = claim
            self.rejectedURLClaim = nil
        } else {
            self.canonicalURL = finalURL
            self.rejectedURLClaim = claim
            if let claim {
                CarterLog.info("Refused off-host canonical/og:url \(claim.absoluteString) on \(finalURL.absoluteString)")
            }
        }
        self.dedupeKey = CanonicalURL.dedupeKey(for: canonicalURL)
        self.host = CanonicalURL.normalizedHost(for: canonicalURL)

        // --- Type -----------------------------------------------------------
        if let typeString = meta.content(forProperty: "og:type"),
           let parsed = URLInformationType.type(for: typeString) {
            self.type = parsed
        } else {
            self.type = defaultType
        }

        // --- Text -----------------------------------------------------------
        self.siteName = meta.content(forProperty: "og:site_name")
        self.title = meta.content(forProperty: "og:title")
            ?? meta.content(forProperty: "twitter:title")
            ?? html.title?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.author = meta.content(forProperty: "author")
            ?? meta.content(forProperty: "article:author")
        self.descriptionText = meta.content(forProperty: "og:description")
            ?? meta.content(forProperty: "description")
            ?? meta.content(forProperty: "twitter:description")
        self.keywords = meta.content(forProperty: "keywords") ?? meta.keywordsFromInlineScript()
        self.section = meta.content(forProperty: "article:section")

        // --- Image ----------------------------------------------------------
        let base = finalURL   // resolve against where we actually are
        self.imageURL = meta.url(forProperty: "og:image:secure_url", relativeTo: base)
            ?? meta.url(forProperty: "og:image:url", relativeTo: base)
            ?? meta.url(forProperty: "og:image", relativeTo: base)
            ?? meta.url(forProperty: "twitter:image", relativeTo: base)
            ?? meta.url(forProperty: "thumbnail", relativeTo: base)

        if let w = meta.content(forProperty: "og:image:width").flatMap(Double.init),
           let h = meta.content(forProperty: "og:image:height").flatMap(Double.init),
           w > 0, h > 0 {
            self.imageSize = ImageSize(width: w, height: h)
        } else {
            self.imageSize = nil
        }

        // --- Dates ----------------------------------------------------------
        let raw = meta.content(forProperty: "article:modified_time")
            ?? meta.content(forProperty: "article:published_time")
            ?? meta.content(forProperty: "og:updated_time")
            ?? meta.content(forProperty: "og:pubdate")
            ?? meta.content(forProperty: "pubdate")
            ?? meta.content(forProperty: "date")
        self.publishDate = raw
        self.publishedAt = raw.flatMap { DateParsing.date(from: $0, ambiguousZone: ambiguousTimeZone) }

        // --- Icons ----------------------------------------------------------
        self.faviconURL = meta.url(forLinkRel: "shortcut icon", relativeTo: base)
            ?? meta.url(forLinkRel: "icon", relativeTo: base)
        self.appleTouchIconURL = meta.url(forLinkRel: "apple-touch-icon", relativeTo: base)
            ?? meta.url(forLinkRel: "apple-touch-icon-precomposed", relativeTo: base)

        self.twitterCard = TwitterCardInformation(meta: meta, relativeTo: base)
    }
}

// MARK: - Meta reading

/// One place that knows how to ask an HTML head a question.
///
/// 1.x inlined ~30 XPath literals, each repeating the `(@property|@name)`
/// idiom, several with a stray trailing space inside the expression.
struct MetaReader {
    let html: HTMLDocument

    /// `<meta property=… >` or `<meta name=… >`, trimmed, empty treated as absent.
    func content(forProperty property: String) -> String? {
        let escaped = property.replacingOccurrences(of: "\"", with: "")
        let xpath = "//meta[(@property|@name)=\"\(escaped)\"]/@content"
        return html.xpath(xpath).first?.text?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .nilIfEmpty
    }

    func url(forProperty property: String, relativeTo base: URL? = nil) -> URL? {
        content(forProperty: property).flatMap { Self.resolve($0, base: base) }
    }

    /// `<link rel=…  href=…>` from anywhere in the head.
    func url(forLinkRel rel: String, relativeTo base: URL? = nil) -> URL? {
        let escaped = rel.replacingOccurrences(of: "\"", with: "")
        let xpath = "//link[@rel=\"\(escaped)\"]/@href"
        guard let href = html.xpath(xpath).first?.text?
            .trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        else { return nil }
        return Self.resolve(href, base: base)
    }

    private static func resolve(_ string: String, base: URL?) -> URL? {
        guard let url = URL(string: string, relativeTo: base)?.absoluteURL else { return nil }
        // Reject javascript:, data:, file: wherever a URL enters.
        return CanonicalURL.isFetchableWebURL(url) ? url : nil
    }

    /// Some CMSes only put tags in an inline `var keyword = [...]`.
    ///
    /// 1.x sliced this with `item[start...end]` and no ordering check, so any
    /// script whose text had `]` before `[` crashed the process with
    /// "Range requires lowerBound <= upperBound" — on attacker-controlled HTML.
    func keywordsFromInlineScript() -> String? {
        for node in html.xpath("//script[@type=\"text/javascript\"]") {
            guard let text = node.text, text.contains("var keyword") else { continue }
            for statement in text.components(separatedBy: ";") {
                guard statement.contains("var keyword"),
                      let open = statement.firstIndex(of: "["),
                      // The FIRST close bracket AFTER the open one. `lastIndex`
                      // overshoots: WordPress writes `var keyword = [...] || []`,
                      // and the last `]` is the empty fallback array, which
                      // swallows `] || [` into the tags.
                      let close = statement[statement.index(after: open)...].firstIndex(of: "]")
                else { continue }
                let inner = statement[statement.index(after: open)..<close]
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if !inner.isEmpty { return inner }
            }
        }
        return nil
    }
}

extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
