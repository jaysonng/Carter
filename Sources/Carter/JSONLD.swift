//
//  JSONLD.swift
//
//  schema.org NewsArticle — the richest, most consistent source on a news page.
//

import Foundation
import Kanna

/// Reads `<script type="application/ld+json">` and answers questions about the
/// article it describes.
///
/// Open Graph is a lowest common denominator: every publisher emits a few tags
/// and then diverges. schema.org is what news CMSes actually populate, and it
/// carries fields `og:` has no equivalent for — `articleSection`, `keywords`,
/// a real author name, and separate published/modified timestamps.
///
/// Sampling four unrelated news sites, all four emitted a `NewsArticle` block
/// while only some emitted useful `og:` beyond title and image; one published
/// no `keywords` meta tag at all yet listed four in JSON-LD. Reading it is
/// usually the difference between a bare title and a usable record.
struct JSONLD {

    /// Every node found, flattened out of `@graph`, keyed by `@id` where present.
    private let nodes: [[String: Any]]
    private let byID: [String: [String: Any]]

    /// The article node, if the page describes one.
    let article: [String: Any]?

    init?(html: HTMLDocument) {
        var found: [[String: Any]] = []

        for script in html.xpath("//script[@type=\"application/ld+json\"]") {
            guard let text = script.text,
                  let data = text.data(using: .utf8),
                  let parsed = try? JSONSerialization.jsonObject(with: data)
            else { continue }
            found.append(contentsOf: Self.flatten(parsed))
        }

        guard !found.isEmpty else { return nil }
        self.nodes = found

        var index: [String: [String: Any]] = [:]
        for node in found {
            if let id = node["@id"] as? String { index[id] = node }
        }
        self.byID = index

        // Prefer the most specific article type the page offers.
        let ranked = ["NewsArticle", "ReportageNewsArticle", "Article",
                      "BlogPosting", "WebPage"]
        self.article = ranked.lazy
            .compactMap { wanted in found.first { Self.types(of: $0).contains(wanted) } }
            .first
    }

    /// `@graph` containers and arrays are unwrapped so every node is reachable.
    private static func flatten(_ value: Any) -> [[String: Any]] {
        if let array = value as? [Any] { return array.flatMap(flatten) }
        guard let object = value as? [String: Any] else { return [] }
        if let graph = object["@graph"] {
            return flatten(graph) + [object.filter { $0.key != "@graph" }]
        }
        return [object]
    }

    private static func types(of node: [String: Any]) -> [String] {
        if let single = node["@type"] as? String { return [single] }
        if let many = node["@type"] as? [String] { return many }
        return []
    }

    /// Follow an `{"@id": …}` reference back into the graph.
    /// Publishers commonly write `author` as a bare reference into their own
    /// `@graph`, so reading it naively gives a URL where a name should be.
    private func resolve(_ value: Any?) -> Any? {
        guard let ref = value as? [String: Any],
              ref.count == 1, let id = ref["@id"] as? String
        else { return value }
        return byID[id] ?? value
    }

    private func string(_ key: String) -> String? {
        guard let article else { return nil }
        if let s = article[key] as? String {
            return s.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        }
        return nil
    }

    // MARK: - Fields

    var headline: String? { string("headline") ?? string("name") }
    var summary: String?  { string("description") }
    var section: String?  { list("articleSection").first }

    /// When the article was FIRST published. Distinct from `modified` — 1.x
    /// preferred `article:modified_time`, so a lightly-edited old story looked
    /// brand new in a feed sorted by date.
    var published: String? { string("datePublished") }
    var modified: String?  { string("dateModified") }

    /// Author name, following an `@id` reference when the page uses one.
    var author: String? {
        guard let article else { return nil }
        let value = resolve(article["author"])
        if let name = (value as? [String: Any])?["name"] as? String { return name.nilIfEmpty }
        if let s = value as? String { return s.nilIfEmpty }
        if let many = value as? [Any] {
            let names = many.compactMap { item -> String? in
                if let n = (resolve(item) as? [String: Any])?["name"] as? String { return n }
                return item as? String
            }
            return names.isEmpty ? nil : names.joined(separator: ", ")
        }
        return nil
    }

    var publisher: String? {
        guard let article else { return nil }
        return ((resolve(article["publisher"]) as? [String: Any])?["name"] as? String)?.nilIfEmpty
    }

    var imageURL: String? {
        guard let article else { return nil }
        let value = resolve(article["image"])
        if let s = value as? String { return s }
        if let object = value as? [String: Any] { return object["url"] as? String }
        if let many = value as? [Any] {
            for item in many {
                if let s = resolve(item) as? String { return s }
                if let o = resolve(item) as? [String: Any], let u = o["url"] as? String { return u }
            }
        }
        return nil
    }

    var keywords: [String] { list("keywords") }

    /// schema.org allows a comma-joined string OR an array; publishers use both.
    private func list(_ key: String) -> [String] {
        guard let article, let value = article[key] else { return [] }
        if let s = value as? String {
            return s.components(separatedBy: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        }
        if let many = value as? [Any] {
            return many.compactMap { ($0 as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        }
        return []
    }
}
