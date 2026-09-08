import XCTest
@testable import Carter

/// Tests that hit real publishers. OPT-IN: they need the network, they depend
/// on markup Carter does not control, and a red suite caused by someone else's
/// CMS teaches nothing. Run with:
///
///     CARTER_LIVE=1 swift test
///
/// 1.x ran these by default, so the suite failed whenever a site changed, was
/// slow, or was unreachable.
final class LiveFetchTests: XCTestCase {

    private var live: Bool { ProcessInfo.processInfo.environment["CARTER_LIVE"] == "1" }

    private func skipUnlessLive() throws {
        try XCTSkipUnless(live, "Set CARTER_LIVE=1 to run tests that fetch real sites.")
    }

    func testFetchesAPhilippineNewsArticle() async throws {
        try skipUnlessLive()
        let url = URL(string: "https://newsinfo.inquirer.net/")!
        let info = try await url.carterInformation()
        XCTAssertNotNil(info.title)
        XCTAssertNotNil(info.dedupeKey)
        XCTAssertEqual(info.host, "inquirer.net")
    }

    func testAllowListRefusesAnUnapprovedPublisher() async throws {
        try skipUnlessLive()
        var config = CarterConfiguration()
        config.isHostAllowed = { $0 == "inquirer.net" }
        do {
            _ = try await Carter(configuration: config)
                .information(for: URL(string: "https://example.com/")!)
            XCTFail("Expected the allow-list to refuse example.com")
        } catch CarterError.hostNotAllowed(let host) {
            XCTAssertEqual(host, "example.com")
        }
    }

    func testTimeoutSurfacesAsTransportError() async throws {
        try skipUnlessLive()
        var config = CarterConfiguration()
        config.timeout = 0.001
        do {
            _ = try await Carter(configuration: config)
                .information(for: URL(string: "https://example.com/")!)
            XCTFail("Expected a timeout")
        } catch CarterError.transport {
            // expected
        }
    }
}
