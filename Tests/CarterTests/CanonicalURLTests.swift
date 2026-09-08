import XCTest
@testable import Carter

/// The capability 1.x was believed to have and did not.
final class CanonicalURLTests: XCTestCase {

    private func key(_ s: String) -> String? {
        CanonicalURL.dedupeKey(for: URL(string: s)!)
    }

    func testCampaignParametersDoNotCreateADuplicate() {
        // The case that matters: the same article shared from Facebook, from a
        // newsletter, and typed by hand.
        let plain = key("https://www.inquirer.net/news/story-123")
        XCTAssertEqual(plain, key("https://www.inquirer.net/news/story-123?utm_source=facebook&utm_medium=social"))
        XCTAssertEqual(plain, key("https://www.inquirer.net/news/story-123?fbclid=IwAR0abc"))
        XCTAssertEqual(plain, key("https://inquirer.net/news/story-123"))      // www
        XCTAssertEqual(plain, key("http://www.inquirer.net/news/story-123"))   // scheme
        XCTAssertEqual(plain, key("https://www.inquirer.net/news/story-123/")) // trailing slash
        XCTAssertEqual(plain, key("https://www.inquirer.net/news/story-123#comments")) // fragment
        XCTAssertEqual(plain, key("https://WWW.INQUIRER.NET/news/story-123"))  // case
    }

    func testParameterOrderIsNotADistinction() {
        XCTAssertEqual(key("https://site.com/a?b=2&a=1"), key("https://site.com/a?a=1&b=2"))
    }

    func testMeaningfulParametersAreKept() {
        // Dropping these would collapse DIFFERENT articles into one — worse
        // than missing a duplicate, so the tracking list stays narrow.
        XCTAssertNotEqual(key("https://site.com/read?id=1"), key("https://site.com/read?id=2"))
        XCTAssertNotEqual(key("https://site.com/a"), key("https://site.com/b"))
        XCTAssertNotEqual(key("https://a.com/x"), key("https://b.com/x"))
    }

    func testNonWebSchemesAreRefused() {
        // 1.x wrote a page's og:url over the requested URL with a bare
        // URL(string:), so these could be stored on a PostArticle.
        XCTAssertFalse(CanonicalURL.isFetchableWebURL(URL(string: "javascript:alert(1)")!))
        XCTAssertFalse(CanonicalURL.isFetchableWebURL(URL(string: "data:text/html,<script>")!))
        XCTAssertFalse(CanonicalURL.isFetchableWebURL(URL(string: "file:///etc/passwd")!))
        XCTAssertTrue(CanonicalURL.isFetchableWebURL(URL(string: "https://site.com/a")!))
    }

    func testNormalizedHostForAllowListing() {
        XCTAssertEqual(CanonicalURL.normalizedHost(for: URL(string: "https://WWW.Inquirer.net/x")!), "inquirer.net")
        XCTAssertEqual(CanonicalURL.normalizedHost(for: URL(string: "https://news.abs-cbn.com./x")!), "news.abs-cbn.com")
    }
}
