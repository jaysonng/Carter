import XCTest
@testable import Carter

/// Edge cases found by running real URLs through the CLI.
final class RootPathKeyTests: XCTestCase {

    /// Found by pasting `https://bworldonline.com` with no trailing slash: a
    /// bare host has an EMPTY path, the same host with "/" has "/", and they
    /// keyed differently — a duplicate that slips straight through.
    func testBareHostAndTrailingSlashAgree() {
        XCTAssertEqual(CanonicalURL.dedupeKey(for: URL(string: "https://bworldonline.com")!),
                       CanonicalURL.dedupeKey(for: URL(string: "https://bworldonline.com/")!))
    }

    func testRootKeepsItsSlashAndDeeperPathsDoNot() {
        XCTAssertEqual(CanonicalURL.dedupeKey(for: URL(string: "https://site.com")!),
                       "https://site.com/")
        XCTAssertEqual(CanonicalURL.dedupeKey(for: URL(string: "https://site.com/a/b/")!),
                       "https://site.com/a/b")
    }

    func testRootVariantsAllAgree() {
        let keys = [
            "https://bworldonline.com",
            "https://bworldonline.com/",
            "http://www.bworldonline.com",
            "https://WWW.BWorldOnline.com/",
            "https://bworldonline.com/?utm_source=fb",
            "https://bworldonline.com/#top",
        ].map { CanonicalURL.dedupeKey(for: URL(string: $0)!) }
        XCTAssertEqual(Set(keys).count, 1, "all spellings of the homepage are one document: \(keys)")
    }
}
