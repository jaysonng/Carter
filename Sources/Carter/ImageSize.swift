//
//  ImageSize.swift
//

import Foundation

/// The pixel size of a preview image.
///
/// A plain struct, not `CGSize`: CoreGraphics does not exist on Linux, and the
/// server is where link ingestion belongs. On Apple platforms `cgSize` bridges
/// back, so an existing `CGSize` call site changes by one property access.
public struct ImageSize: Equatable, Hashable, Sendable, Codable {
    public let width: Double
    public let height: Double

    public init(width: Double, height: Double) {
        self.width = width
        self.height = height
    }
}

#if canImport(CoreGraphics)
import CoreGraphics

public extension ImageSize {
    var cgSize: CGSize { CGSize(width: width, height: height) }
}
#endif
