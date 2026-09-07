import XCTest
import Kanna
@testable import Carter

final class ParsingTests: XCTestCase {

    private func info(_ html: String,
                      from: String = "https://publisher.com/article",
                      final: String? = nil) -> URLInformation {
        let origin = URL(string: from)!
        let end = URL(string: final ?? from)!
        return URLInformation(originalURL: origin,
                              finalURL: end,
                              html: try? HTML(html: html, encoding: .utf8),
                              mimeType: "text/html",
                              statusCode: 200,
                              defaultType: .website)
    }

    /// The crash, verified fixed. Any script with `]` before `[` used to trap
    /// with "Range requires lowerBound <= upperBound" on attacker HTML.
    func testInlineKeywordScraperSurvivesReversedBrackets() {
        let html = """
        <html><head><title>T</title></head><body>
        <script type="text/javascript">var keyword = ] not an array [ ;</script>
        </body></html>
        """
        let result = info(html)          // must not trap
        XCTAssertEqual(result.title, "T")
    }

    func testInlineKeywordScraperStillReadsRealArrays() {
        let html = """
        <html><head><title>T</title></head><body>
        <script type="text/javascript">var keyword = ["manila","flood"];</script>
        </body></html>
        """
        // Quotes are stripped now that tags are parsed rather than sliced raw.
        XCTAssertEqual(info(html).keywords, "manila,flood")
        XCTAssertEqual(info(html).tags, ["manila", "flood"])
    }

    /// The security fix: a page cannot redirect where its own link is stored.
    func testOffHostCanonicalClaimIsRefused() {
        let html = """
        <html><head><link rel="canonical" href="https://evil.example/steal">
        <meta property="og:url" content="https://evil.example/steal"></head></html>
        """
        let result = info(html, from: "https://publisher.com/article")
        XCTAssertEqual(result.canonicalURL.absoluteString, "https://publisher.com/article")
        XCTAssertEqual(result.rejectedURLClaim?.absoluteString, "https://evil.example/steal")
    }

    func testSameHostCanonicalClaimIsAccepted() {
        let html = """
        <html><head><link rel="canonical" href="https://publisher.com/canonical-path"></head></html>
        """
        let result = info(html, from: "https://publisher.com/article?utm_source=x")
        XCTAssertEqual(result.canonicalURL.absoluteString, "https://publisher.com/canonical-path")
        XCTAssertNil(result.rejectedURLClaim)
    }

    func testCanonicalIsPreferredOverOgURL() {
        let html = """
        <html><head><link rel="canonical" href="https://publisher.com/real">
        <meta property="og:url" content="https://publisher.com/og"></head></html>
        """
        XCTAssertEqual(info(html).canonicalURL.absoluteString, "https://publisher.com/real")
    }

    /// Relative assets must resolve against where we ARE, not a page's claim.
    func testRelativeImageResolvesAgainstFinalURL() {
        let html = """
        <html><head><meta property="og:image" content="/img/hero.jpg"></head></html>
        """
        XCTAssertEqual(info(html).imageURL?.absoluteString, "https://publisher.com/img/hero.jpg")
    }

    func testJavascriptImageURLIsRefused() {
        let html = #"<html><head><meta property="og:image" content="javascript:alert(1)"></head></html>"#
        XCTAssertNil(info(html).imageURL)
    }

    func testTitleFallsBackToTitleTag() {
        XCTAssertEqual(info("<html><head><title>Fallback</title></head></html>").title, "Fallback")
        let og = #"<html><head><title>Ignored</title><meta property="og:title" content="Preferred"></head></html>"#
        XCTAssertEqual(info(og).title, "Preferred")
    }

    /// 1.x read og:type here, so cardType was .other for every page.
    func testTwitterCardTypeReadsTwitterCardTag() {
        let html = """
        <html><head><meta name="twitter:card" content="summary_large_image">
        <meta property="og:type" content="article">
        <meta name="twitter:site" content="@inquirerdotnet"></head></html>
        """
        let card = info(html).twitterCard
        XCTAssertEqual(card?.cardType, .summaryLargeImage)
        XCTAssertEqual(card?.account, "inquirerdotnet")
        XCTAssertNotNil(card?.cardType.minimumImageSize)
    }

    func testTwitterCardIsNilWhenAbsent() {
        XCTAssertNil(info("<html><head><title>x</title></head></html>").twitterCard)
    }

    func testPublishDateIsParsedAndRawIsKept() {
        let html = #"<html><head><meta property="article:published_time" content="2026-09-06T08:30:00Z"></head></html>"#
        let result = info(html)
        XCTAssertEqual(result.publishDate, "2026-09-06T08:30:00Z")   // 1.x contract
        XCTAssertNotNil(result.publishedAt)                          // 2.0 addition
    }

    func testEqualityIsByDocumentNotByRawURL() {
        let a = info("<html><head><title>x</title></head></html>", from: "https://publisher.com/a?utm_source=fb")
        let b = info("<html><head><title>x</title></head></html>", from: "https://publisher.com/a")
        XCTAssertEqual(a, b)
    }

    func testMimeTypeClassificationWithoutAVFoundation() {
        XCTAssertEqual(URLInformationType.type(forMimeType: "audio/mpeg"), .fileAudio)
        XCTAssertEqual(URLInformationType.type(forMimeType: "video/mp4"), .fileVideo)
        XCTAssertEqual(URLInformationType.type(forMimeType: "image/png"), .fileImage)
        XCTAssertEqual(URLInformationType.type(forMimeType: "text/html; charset=utf-8"), .website)
    }
}

/// Regressions from running Carter against a real inquirer.net article.
final class InquirerRegressionTests: XCTestCase {

    /// inquirer.net means UTC+8 by "PST"; Foundation means UTC−8. A 16-hour
    /// error that moves the article to the wrong day.
    func testPhilippineStandardTimeIsNotReadAsPacific() {
        let raw = "Fri, 04 Sep 2026 22:13:46 PST"
        let manila = DateParsing.date(from: raw, ambiguousZone: TimeZone(identifier: "Asia/Manila"))
        XCTAssertNotNil(manila)
        // 22:13:46 +08 on the 4th == 14:13:46Z on the 4th.
        XCTAssertEqual(ISO8601DateFormatter().string(from: manila!), "2026-09-04T14:13:46Z")

        // And the same string in a Pacific deployment stays Pacific.
        let pacific = DateParsing.date(from: raw, ambiguousZone: TimeZone(identifier: "America/Los_Angeles"))
        XCTAssertEqual(ISO8601DateFormatter().string(from: pacific!), "2026-09-05T05:13:46Z")
    }

    func testExplicitOffsetsAreNeverReinterpreted() {
        let d = DateParsing.date(from: "2026-09-04T22:13:46+08:00",
                                 ambiguousZone: TimeZone(identifier: "America/Los_Angeles"))
        XCTAssertEqual(ISO8601DateFormatter().string(from: d!), "2026-09-04T14:13:46Z")
    }

    /// WordPress writes `var keyword = [...] || []`; taking the LAST `]`
    /// swallowed `] || [` into the tags.
    func testKeywordScraperStopsAtTheFirstClosingBracket() {
        let html = """
        <html><head><title>T</title></head><body>
        <script type="text/javascript">var keyword = ["Flood","Real Estate"] || [];</script>
        </body></html>
        """
        let info = URLInformation(originalURL: URL(string: "https://business.inquirer.net/a")!,
                                  finalURL: URL(string: "https://business.inquirer.net/a")!,
                                  html: try? HTML(html: html, encoding: .utf8),
                                  mimeType: "text/html", statusCode: 200, defaultType: .website)
        XCTAssertEqual(info.tags, ["Flood", "Real Estate"])
        XCTAssertFalse(info.keywords?.contains("||") ?? false)
    }
}
