//
//  AddressPolicy.swift
//
//  Which network destinations Carter refuses to contact.
//
//  A link preview fetches a URL somebody else chose, from inside YOUR network.
//  Without this, `http://127.0.0.1:1110/parse/...` — or a public page that
//  redirects there — makes the server request its own internal services.
//
//  ⚠️ Residual risk, stated rather than hidden: URLSession resolves the name
//  again when it connects, so a hostile DNS server can answer differently the
//  second time (DNS rebinding). An allow-list of publisher domains plus an
//  egress firewall is the complete answer; this closes the direct and the
//  redirect cases.
//

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking   // URLSession and its delegate types live here on Linux
#endif
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#endif

enum AddressPolicy {

    /// True when `host` is, or resolves to, an address that is not on the
    /// public internet. A name that does not resolve is NOT internal — the
    /// fetch will fail on its own.
    static func isInternal(host rawHost: String) -> Bool {
        var host = rawHost.lowercased()
        if host.hasPrefix("["), host.hasSuffix("]") { host = String(host.dropFirst().dropLast()) }
        if host == "localhost" || host.hasSuffix(".localhost") { return true }

        if let v4 = ipv4(host) { return isInternal(v4: v4) }
        if let v6 = ipv6(host) { return isInternal(v6: v6) }

        return resolve(host).contains { address in
            switch address {
            case .v4(let b): return isInternal(v4: b)
            case .v6(let b): return isInternal(v6: b)
            }
        }
    }

    // MARK: - Ranges

    static func isInternal(v4 b: [UInt8]) -> Bool {
        switch (b[0], b[1]) {
        case (0, _), (10, _), (127, _):        return true   // this-network, private, loopback
        case (100, 64...127):                  return true   // carrier-grade NAT
        case (169, 254):                       return true   // link-local (cloud metadata lives here)
        case (172, 16...31):                   return true   // private
        case (192, 168):                       return true   // private
        case (192, 0) where b[2] == 0:         return true   // IETF protocol assignments
        case (198, 18...19):                   return true   // benchmarking
        case (224...255, _):                   return true   // multicast, reserved, broadcast
        default:                               return false
        }
    }

    static func isInternal(v6 b: [UInt8]) -> Bool {
        if b.allSatisfy({ $0 == 0 }) { return true }                              // ::
        if b[0..<15].allSatisfy({ $0 == 0 }) && b[15] == 1 { return true }        // ::1
        if b[0..<10].allSatisfy({ $0 == 0 }) && b[10] == 0xff && b[11] == 0xff {  // ::ffff:a.b.c.d
            return isInternal(v4: Array(b[12..<16]))
        }
        if b[0] & 0xfe == 0xfc { return true }                                    // fc00::/7 unique local
        if b[0] == 0xfe && b[1] & 0xc0 == 0x80 { return true }                    // fe80::/10 link-local
        if b[0] == 0xff { return true }                                           // multicast
        return false
    }

    // MARK: - Parsing and resolution

    enum Address { case v4([UInt8]), v6([UInt8]) }

    static func ipv4(_ s: String) -> [UInt8]? {
        var a = in_addr()
        guard inet_pton(AF_INET, s, &a) == 1 else { return nil }
        return withUnsafeBytes(of: &a) { Array($0) }
    }

    static func ipv6(_ s: String) -> [UInt8]? {
        var a = in6_addr()
        guard inet_pton(AF_INET6, s, &a) == 1 else { return nil }
        return withUnsafeBytes(of: &a) { Array($0) }
    }

    static func resolve(_ host: String) -> [Address] {
        var hints = addrinfo()
        hints.ai_family = AF_UNSPEC
        #if canImport(Glibc) || canImport(Musl)
        hints.ai_socktype = Int32(SOCK_STREAM.rawValue)
        #else
        hints.ai_socktype = SOCK_STREAM
        #endif
        var result: UnsafeMutablePointer<addrinfo>?
        guard getaddrinfo(host, nil, &hints, &result) == 0, let first = result else { return [] }
        defer { freeaddrinfo(first) }

        var out: [Address] = []
        var cursor: UnsafeMutablePointer<addrinfo>? = first
        while let info = cursor {
            if let sa = info.pointee.ai_addr {
                switch Int32(info.pointee.ai_family) {
                case AF_INET:
                    sa.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { p in
                        var a = p.pointee.sin_addr
                        out.append(.v4(withUnsafeBytes(of: &a) { Array($0) }))
                    }
                case AF_INET6:
                    sa.withMemoryRebound(to: sockaddr_in6.self, capacity: 1) { p in
                        var a = p.pointee.sin6_addr
                        out.append(.v6(withUnsafeBytes(of: &a) { Array($0) }))
                    }
                default: break
                }
            }
            cursor = info.pointee.ai_next
        }
        return out
    }
}

/// Refuses every redirect, so Carter can check each hop BEFORE requesting it.
final class RedirectRefuser: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    func urlSession(_ session: URLSession, task: URLSessionTask,
                    willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest,
                    completionHandler: @escaping (URLRequest?) -> Void) {
        completionHandler(nil)
    }
}
