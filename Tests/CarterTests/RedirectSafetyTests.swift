//
//  RedirectSafetyTests.swift
//
//  Every redirect hop is vetted BEFORE it is requested, and non-public
//  addresses are refused. The proof that matters is the canary: a server the
//  redirect points at must receive NO request at all.
//
//  Uses two throwaway python3 HTTP servers on loopback (macOS dev machines;
//  skipped where python3 is absent).
//

import XCTest
@testable import Carter

final class AddressPolicyTests: XCTestCase {

    func testLiteralsAndNames() {
        for host in ["127.0.0.1", "10.1.2.3", "172.16.0.1", "192.168.68.75", "169.254.169.254",
                         "100.64.0.1", "0.0.0.0", "::1", "[::1]", "fd00::1", "fe80::1",
                         "::ffff:127.0.0.1", "localhost", "api.localhost"] {
            XCTAssertTrue(AddressPolicy.isInternal(host: host), host)
        }
        for host in ["8.8.8.8", "1.1.1.1", "172.32.0.1", "2606:4700:4700::1111"] {
            XCTAssertFalse(AddressPolicy.isInternal(host: host), host)
        }
    }
}

#if os(macOS)
final class RedirectSafetyTests: XCTestCase {

    private var processes: [Process] = []
    private var dir: URL!

    override func setUpWithError() throws {
        guard FileManager.default.isExecutableFile(atPath: "/usr/bin/python3") else {
            throw XCTSkip("python3 not available")
        }
        dir = FileManager.default.temporaryDirectory.appendingPathComponent("carter-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    override func tearDown() {
        processes.forEach { $0.terminate() }
        try? FileManager.default.removeItem(at: dir)
    }

    /// Start a loopback server; returns its port once it is listening.
    /// `redirectTo` nil → a canary that records every request it receives.
    private func server(redirectTo: String?) throws -> Int {
        let portFile = dir.appendingPathComponent(UUID().uuidString)
        let hits = dir.appendingPathComponent("hits")
        let script = """
        import http.server, socketserver, sys
        class H(http.server.BaseHTTPRequestHandler):
            def do_GET(self):
                \(redirectTo.map { "self.send_response(302); self.send_header('Location', '\($0)'); self.end_headers()" }
                  ?? "open('\(hits.path)','a').write(self.path+'\\n'); self.send_response(200); self.send_header('Content-Type','text/html'); self.end_headers(); self.wfile.write(b'<html><head><title>canary</title></head></html>')")
            def log_message(self, *a): pass
        s = socketserver.TCPServer(('127.0.0.1', 0), H)
        open('\(portFile.path)','w').write(str(s.server_address[1]))
        s.serve_forever()
        """
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
        p.arguments = ["-c", script]
        try p.run()
        processes.append(p)
        for _ in 0..<100 {
            if let s = try? String(contentsOf: portFile, encoding: .utf8), let port = Int(s) { return port }
            Thread.sleep(forTimeInterval: 0.05)
        }
        throw XCTSkip("helper server did not start")
    }

    private var canaryHits: Int {
        ((try? String(contentsOf: dir.appendingPathComponent("hits"), encoding: .utf8)) ?? "")
            .split(separator: "\n").count
    }

    /// The probe can SEE the hole: a caller-supplied session follows the
    /// redirect itself, and the canary IS reached. Without this, a zero below
    /// could just mean the helper never worked.
    func testProbeSeesIt_aSessionThatFollowsRedirects_reachesTheCanary() async throws {
        let canary = try server(redirectTo: nil)
        let start = try server(redirectTo: "http://localhost:\(canary)/secret")
        var config = CarterConfiguration(timeout: 5)
        config.blocksNonPublicAddresses = false
        config.isHostAllowed = { $0 == "127.0.0.1" }
        let carter = Carter(configuration: config, session: URLSession(configuration: .ephemeral))
        _ = try? await carter.information(for: URL(string: "http://127.0.0.1:\(start)/")!)
        XCTAssertEqual(canaryHits, 1, "the probe must be able to see a request reach the canary")
    }

    /// An allowed host redirecting to a disallowed one: refused, and the
    /// disallowed host is never contacted.
    func testRedirectToDisallowedHost_isRefusedBeforeItIsRequested() async throws {
        let canary = try server(redirectTo: nil)
        let start = try server(redirectTo: "http://localhost:\(canary)/secret")
        var config = CarterConfiguration(timeout: 5)
        config.blocksNonPublicAddresses = false
        config.isHostAllowed = { $0 == "127.0.0.1" }
        do {
            _ = try await Carter(configuration: config).information(for: URL(string: "http://127.0.0.1:\(start)/")!)
            XCTFail("should have refused the redirect")
        } catch let error as CarterError {
            XCTAssertEqual(error, .hostNotAllowed("localhost"))
        }
        XCTAssertEqual(canaryHits, 0, "the canary must receive no request")
    }

    /// With the default address policy, a loopback target is refused outright.
    func testLoopbackTarget_isRefusedByDefault() async throws {
        let canary = try server(redirectTo: nil)
        do {
            _ = try await Carter(configuration: .init(timeout: 5))
                .information(for: URL(string: "http://127.0.0.1:\(canary)/")!)
            XCTFail("should have refused a loopback address")
        } catch let error as CarterError {
            XCTAssertEqual(error, .addressNotAllowed("127.0.0.1"))
        }
        XCTAssertEqual(canaryHits, 0)
    }

    func testRedirectLoop_stopsAtTheLimit() async throws {
        // A server that redirects to itself forever.
        let portFile = try server(redirectTo: "/again")
        var config = CarterConfiguration(timeout: 5, maximumRedirects: 3)
        config.blocksNonPublicAddresses = false
        do {
            _ = try await Carter(configuration: config).information(for: URL(string: "http://127.0.0.1:\(portFile)/")!)
            XCTFail("should have stopped")
        } catch let error as CarterError {
            XCTAssertEqual(error, .tooManyRedirects(3))
        }
    }
}
#endif
