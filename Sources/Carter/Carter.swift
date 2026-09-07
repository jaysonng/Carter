//
//  Carter.swift
//
//  Created by Jayson Ng on 11/24/21.
//
import Foundation
import Kanna

#if canImport(FoundationNetworking)
import FoundationNetworking   // URLSession lives here on Linux
#endif

/// How Carter fetches.
public struct CarterConfiguration: Sendable {

    /// Per-request timeout. 1.x used `URLSession.shared` untouched, whose
    /// RESOURCE timeout defaults to seven days — a hung publisher could pin a
    /// request open effectively forever.
    public var timeout: TimeInterval

    /// Hard cap on the body Carter will read. A link is a `<head>`; a page that
    /// wants to hand us 200 MB is not one we need to parse. 1.x buffered the
    /// whole body and then copied it into a String.
    public var maximumBodyBytes: Int

    /// Called with the host of every URL about to be fetched, INCLUDING after
    /// a redirect. Return false to refuse. This is where a publisher allow-list
    /// belongs — Carter never decides policy.
    public var isHostAllowed: (@Sendable (String) -> Bool)?

    /// Sent as `User-Agent`. Some publishers serve a stub to unknown agents.
    public var userAgent: String

    /// Type assumed when a page declares no `og:type`.
    public var defaultType: URLInformationType

    public init(timeout: TimeInterval = 15,
                maximumBodyBytes: Int = 5 * 1024 * 1024,
                isHostAllowed: (@Sendable (String) -> Bool)? = nil,
                userAgent: String = "Carter/2.0 (+link preview)",
                defaultType: URLInformationType = .website) {
        self.timeout = timeout
        self.maximumBodyBytes = maximumBodyBytes
        self.isHostAllowed = isHostAllowed
        self.userAgent = userAgent
        self.defaultType = defaultType
    }
}

/// Scrapes Open Graph / meta information from a URL.
///
/// 2.0 is `async` throughout. 1.x bridged Combine to a `CheckedContinuation`
/// through a single stored `AnyCancellable`, which had three consequences: the
/// sink captured `self` strongly so no Carter was ever deallocated; a second
/// call replaced the stored subscription and left the first continuation
/// unresumed, hanging its caller forever; and values were delivered on a
/// `.concurrent` queue, breaking Combine's serial-delivery contract.
public struct Carter: Sendable {

    public let configuration: CarterConfiguration
    private let session: URLSession

    public init(configuration: CarterConfiguration = .init(), session: URLSession? = nil) {
        self.configuration = configuration
        if let session {
            self.session = session
        } else {
            let config = URLSessionConfiguration.ephemeral
            config.timeoutIntervalForRequest = configuration.timeout
            config.timeoutIntervalForResource = configuration.timeout
            config.httpAdditionalHeaders = ["User-Agent": configuration.userAgent]
            self.session = URLSession(configuration: config)
        }
    }

    /// Fetch a URL and return what could be learned about it.
    ///
    /// Throws `CarterError` — a specific one. 1.x collapsed every failure into
    /// `.failedToGetURLInformation`, so a caller could not tell a blocked
    /// domain from a timeout.
    public func information(for url: URL) async throws -> URLInformation {
        guard CanonicalURL.isFetchableWebURL(url) else {
            throw CarterError.unsupportedScheme(url.scheme ?? "none")
        }
        try check(host: url)

        let (data, response) = try await load(url)

        // Where we actually ended up. The allow-list must see this, not just
        // the URL the user pasted — 1.x discarded it entirely.
        let finalURL = response.url ?? url
        if finalURL != url { try check(host: finalURL) }

        if let http = response as? HTTPURLResponse,
           !(200..<300).contains(http.statusCode) {
            throw CarterError.httpError(statusCode: http.statusCode, url: finalURL)
        }
        let statusCode = (response as? HTTPURLResponse)?.statusCode

        // Not HTML: still describable by MIME type, so return rather than throw.
        let mime = response.mimeType?.lowercased()
        guard let mime, mime.contains("html") || mime.contains("xml") else {
            return URLInformation(originalURL: url, finalURL: finalURL, html: nil,
                                  mimeType: response.mimeType, statusCode: statusCode,
                                  defaultType: configuration.defaultType)
        }

        let document = try parse(data, mimeType: response.mimeType)
        return URLInformation(originalURL: url, finalURL: finalURL, html: document,
                              mimeType: response.mimeType, statusCode: statusCode,
                              defaultType: configuration.defaultType)
    }

    // MARK: - Internals

    private func check(host url: URL) throws {
        guard let allow = configuration.isHostAllowed else { return }
        guard let host = CanonicalURL.normalizedHost(for: url) else {
            throw CarterError.invalidURL(url.absoluteString)
        }
        guard allow(host) else { throw CarterError.hostNotAllowed(host) }
    }

    private func load(_ url: URL) async throws -> (Data, URLResponse) {
        var request = URLRequest(url: url)
        request.timeoutInterval = configuration.timeout
        request.setValue("text/html,application/xhtml+xml", forHTTPHeaderField: "Accept")
        do {
            let (data, response) = try await session.data(for: request)
            guard data.count <= configuration.maximumBodyBytes else {
                throw CarterError.responseTooLarge(bytes: data.count,
                                                   limit: configuration.maximumBodyBytes)
            }
            return (data, response)
        } catch let error as CarterError {
            throw error
        } catch {
            throw CarterError.transport(message: error.localizedDescription)
        }
    }

    /// Decode then parse, honouring the charset the server declared.
    ///
    /// 1.x hardcoded `.utf8` with an `.ascii` fallback and a nested
    /// do/do/catch that retried utf8 with utf8 — which is why its own comment
    /// admitted `.byURL` "does not handle websites with wrong charset".
    private func parse(_ data: Data, mimeType: String?) throws -> HTMLDocument {
        let declared = Self.encoding(fromContentType: mimeType)
        for encoding in [declared, .utf8, .isoLatin1, .windowsCP1252].compactMap({ $0 }) {
            guard let text = String(data: data, encoding: encoding) else { continue }
            if let document = try? HTML(html: text, encoding: encoding) { return document }
        }
        // Last resort: hand libxml2 the bytes and let it sniff.
        if let document = try? HTML(html: data, encoding: .utf8) { return document }
        throw CarterError.htmlParsingFailed
    }

    private static func encoding(fromContentType contentType: String?) -> String.Encoding? {
        guard let contentType,
              let range = contentType.range(of: "charset=", options: .caseInsensitive)
        else { return nil }
        let name = contentType[range.upperBound...]
            .trimmingCharacters(in: CharacterSet(charactersIn: "\"' ;"))
            .lowercased()
        switch name {
        case "utf-8", "utf8":                     return .utf8
        case "iso-8859-1", "latin1", "iso8859-1": return .isoLatin1
        case "windows-1252", "cp1252":            return .windowsCP1252
        case "shift_jis", "shift-jis":            return .shiftJIS
        case "euc-jp":                            return .japaneseEUC
        case "us-ascii", "ascii":                 return .ascii
        default:                                  return nil
        }
    }
}

// MARK: - Convenience

public extension URL {
    /// `try await url.carterInformation()` — the 2.0 spelling of
    /// `url.carter.getURLInformation()`.
    func carterInformation(configuration: CarterConfiguration = .init()) async throws -> URLInformation {
        try await Carter(configuration: configuration).information(for: self)
    }
}
