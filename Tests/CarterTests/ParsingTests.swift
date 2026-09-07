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
        XCTAssertEqual(info(html).keywords, "\"manila\",\"flood\"")
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
