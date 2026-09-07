//
//  CarterError.swift
//
//  Created by Jayson Ng on 11/26/21.
//

import Foundation

/// Why a link could not be turned into a `URLInformation`.
///
/// 1.x collapsed every failure into `failedToGetURLInformation`, which made a
/// blocked domain, a 404, a timeout and a parse failure indistinguishable at
/// the call site — so a caller could not tell the user anything useful, and
/// could not decide whether retrying was worth it.
public enum CarterError: Error, Equatable, CustomStringConvertible {

    /// The string was not a URL, or not one that can be fetched.
    case invalidURL(String)

    /// The scheme is not http/https. Guards against `javascript:`, `data:`,
    /// and `file:` arriving through a page's own `og:url`.
    case unsupportedScheme(String)

    /// The host is not on the caller's allow-list.
    /// Carter never decides policy; the caller supplies `isHostAllowed`.
    case hostNotAllowed(String)

    /// The server answered, but not with success.
    case httpError(statusCode: Int, url: URL)

    /// The response was not HTML (an image, a PDF, a download).
    /// `type` is still usable — see `URLInformation.type`.
    case notHTML(mimeType: String?)

    /// The body exceeded `CarterConfiguration.maximumBodyBytes`.
    case responseTooLarge(bytes: Int, limit: Int)

    /// The bytes could not be decoded as text in any attempted encoding.
    case undecodableBody

    /// libxml2 could not parse the document.
    case htmlParsingFailed

    /// The request timed out or the connection failed.
    case transport(message: String)

    public var description: String {
        switch self {
        case .invalidURL(let s):            return "Not a valid URL: \(s)"
        case .unsupportedScheme(let s):     return "Unsupported URL scheme: \(s). Only http and https are fetched."
        case .hostNotAllowed(let h):        return "This site is not on the allowed list: \(h)"
        case .httpError(let code, let url): return "The site returned HTTP \(code) for \(url.absoluteString)"
        case .notHTML(let mime):            return "That link is not a web page\(mime.map { " (\($0))" } ?? "")."
        case .responseTooLarge(let b, let l): return "The page is too large to read (\(b) bytes, limit \(l))."
        case .undecodableBody:              return "The page's text could not be decoded."
        case .htmlParsingFailed:            return "The page's HTML could not be parsed."
        case .transport(let m):             return "There was a problem reaching the site: \(m)"
        }
    }
}
