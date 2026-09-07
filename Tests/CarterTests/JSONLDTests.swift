import XCTest
import Kanna
@testable import Carter

/// schema.org extraction, modelled on the markup the whitelisted Philippine
/// publishers actually emit.
final class JSONLDTests: XCTestCase {

    private func info(_ html: String) -> URLInformation {
        let u = URL(string: "https://publisher.com/article")!
        return URLInformation(originalURL: u, finalURL: u,
                              html: try? HTML(html: html, encoding: .utf8),
                              mimeType: "text/html", statusCode: 200,
                              defaultType: .website,
                              ambiguousTimeZone: TimeZone(identifier: "Asia/Manila"))
    }

    /// Rappler's shape: an @graph whose article references author and image by
    /// @id. Reading `author` naively yields a URL where a name should be.
    func testGraphReferencesAreResolved() {
        let html = """
        <html><head><script type="application/ld+json">
        {"@graph":[
          {"@type":"Person","@id":"https://p.com/#/person/1","name":"Acor Arceo"},
          {"@type":"ImageObject","@id":"https://p.com/#img","url":"https://p.com/hero.jpg"},
          {"@type":"Organization","@id":"https://p.com/#org","name":"RAPPLER"},
          {"@type":"NewsArticle",
           "headline":"Class suspensions",
           "author":{"@id":"https://p.com/#/person/1"},
           "image":{"@id":"https://p.com/#img"},
           "publisher":{"@id":"https://p.com/#org"},
           "datePublished":"2026-09-07T11:00:32+00:00",
           "dateModified":"2026-09-07T18:27:55+00:00",
           "articleSection":"class suspensions, southwest monsoon",
           "keywords":"class suspensions, southwest monsoon, Philippine News"}
        ]}
        </script></head></html>
        """
        let r = info(html)
        XCTAssertEqual(r.author, "Acor Arceo")          // not the @id URL
        XCTAssertEqual(r.publisherName, "RAPPLER")
        XCTAssertEqual(r.imageURL?.absoluteString, "https://p.com/hero.jpg")
        XCTAssertEqual(r.title, "Class suspensions")
        XCTAssertEqual(r.section, "class suspensions")
        XCTAssertEqual(r.tags, ["class suspensions", "southwest monsoon", "Philippine News"])
    }

    /// PUBLISHED, not MODIFIED. 1.x preferred modified_time, so a story
    /// corrected later sorted as if it were new.
    func testPublishedIsPreferredAndModifiedIsKeptSeparately() {
        let html = """
        <html><head><script type="application/ld+json">
        {"@type":"NewsArticle","headline":"H",
         "datePublished":"2020-01-01T00:00:00+00:00",
         "dateModified":"2026-09-07T18:27:55+00:00"}
        </script></head></html>
        """
        let r = info(html)
        let iso = ISO8601DateFormatter()
        XCTAssertEqual(iso.string(from: r.publishedAt!), "2020-01-01T00:00:00Z")
        XCTAssertEqual(iso.string(from: r.modifiedAt!), "2026-09-07T18:27:55Z")
    }

    /// og: still wins where it is the better source, and JSON-LD fills gaps.
    func testOpenGraphAndJSONLDCombine() {
        let html = """
        <html><head>
        <meta property="og:description" content="OG summary">
        <meta property="og:image" content="https://publisher.com/og.jpg">
        <script type="application/ld+json">
        {"@type":"NewsArticle","headline":"LD headline","description":"LD summary",
         "keywords":["flood","manila"]}
        </script></head></html>
        """
        let r = info(html)
        XCTAssertEqual(r.title, "LD headline")
        XCTAssertEqual(r.descriptionText, "OG summary")
        XCTAssertEqual(r.imageURL?.absoluteString, "https://publisher.com/og.jpg")
        XCTAssertEqual(r.tags, ["flood", "manila"])
    }

    /// article:tag repeats; the old reader took only the first.
    func testRepeatableArticleTagsAreAllCollected() {
        let html = """
        <html><head>
        <meta property="article:tag" content="Flood">
        <meta property="article:tag" content="Habagat">
        <meta name="news_keywords" content="Manila, Rain">
        </head></html>
        """
        XCTAssertEqual(info(html).tags, ["Flood", "Habagat", "Manila", "Rain"])
    }

    func testTagsAreDedupedCaseInsensitivelyWithOrderKept() {
        let html = """
        <html><head>
        <meta property="article:tag" content="Flood">
        <meta name="keywords" content="flood, FLOOD, Manila">
        </head></html>
        """
        XCTAssertEqual(info(html).tags, ["Flood", "Manila"])
    }

    func testPageWithoutJSONLDStillWorks() {
        let html = #"<html><head><meta property="og:title" content="Plain"></head></html>"#
        let r = info(html)
        XCTAssertEqual(r.title, "Plain")
        XCTAssertEqual(r.tags, [])
        XCTAssertNil(r.modifiedAt)
    }

    func testMalformedJSONLDIsIgnoredNotFatal() {
        let html = """
        <html><head><title>Fallback</title>
        <script type="application/ld+json">{ this is not json }</script>
        </head></html>
        """
        XCTAssertEqual(info(html).title, "Fallback")
    }
}

/// Real-world script-tag shapes.
final class InlineScriptTests: XCTestCase {

    private func tags(_ html: String) -> [String] {
        let u = URL(string: "https://p.com/a")!
        return URLInformation(originalURL: u, finalURL: u,
                              html: try? HTML(html: html, encoding: .utf8),
                              mimeType: "text/html", statusCode: 200,
                              defaultType: .website).tags
    }

    /// WP Rocket rewrites the type attribute, so requiring
    /// type="text/javascript" silently lost every tag on those pages.
    func testLazyLoadRewrittenScriptTypeIsStillRead() {
        let html = """
        <html><head></head><body>
        <script type="text/rocketlazyloadscript" data-rocket-type="text/javascript">
          var keyword = ["Arca South","Flood"] || [];
        </script></body></html>
        """
        XCTAssertEqual(tags(html), ["Arca South", "Flood"])
    }

    /// Modern HTML omits type entirely; JavaScript is the default.
    func testScriptWithNoTypeAttributeIsRead() {
        let html = """
        <html><body><script>var keyword = ["Manila"] || [];</script></body></html>
        """
        XCTAssertEqual(tags(html), ["Manila"])
    }
}
