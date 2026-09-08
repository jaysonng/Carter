//
//  TwitterCardInformation.swift
//
//  based on Ocarina by Rens Verhoeven (MIT)
//

import Foundation

/// The `twitter:*` card tags, when a page provides them.
public struct TwitterCardInformation: Equatable, Sendable {

    public let cardType: TwitterCardType
    public let title: String?
    public let descriptionText: String?
    public let imageURL: URL?
    public let url: URL?
    /// `twitter:site`, without the leading `@`.
    public let account: String?
    public let creator: String?

    /// Returns nil when the page has no Twitter card tags at all, so a caller
    /// can tell "absent" from "present but empty".
    init?(meta: MetaReader, relativeTo base: URL?) {
        let rawCard = meta.content(forProperty: "twitter:card")
        let title = meta.content(forProperty: "twitter:title")
        let description = meta.content(forProperty: "twitter:description")
        let image = meta.url(forProperty: "twitter:image", relativeTo: base)
            ?? meta.url(forProperty: "twitter:image:src", relativeTo: base)
        let url = meta.url(forProperty: "twitter:url", relativeTo: base)
        let site = meta.content(forProperty: "twitter:site")
        let creator = meta.content(forProperty: "twitter:creator")

        if rawCard == nil && title == nil && description == nil
            && image == nil && url == nil && site == nil && creator == nil {
            return nil
        }

        // 1.x read `og:type` here, so cardType was `.other` for every page ever
        // parsed and `minimumImageSize` was always nil. The tag is `twitter:card`.
        self.cardType = rawCard.flatMap(TwitterCardType.init(rawValue:)) ?? .other
        self.title = title
        self.descriptionText = description
        self.imageURL = image
        self.url = url
        self.account = site.map { $0.hasPrefix("@") ? String($0.dropFirst()) : $0 }
        self.creator = creator.map { $0.hasPrefix("@") ? String($0.dropFirst()) : $0 }
    }
}

public enum TwitterCardType: String, Equatable, Sendable {
    case summary            = "summary"
    case summaryLargeImage  = "summary_large_image"
    case app                = "app"
    case player             = "player"
    case other              = "other"

    /// Twitter's documented minimum for the card to render an image.
    public var minimumImageSize: ImageSize? {
        switch self {
        case .summary:           return ImageSize(width: 144, height: 144)
        case .summaryLargeImage: return ImageSize(width: 300, height: 157)
        case .player:            return ImageSize(width: 262, height: 262)
        case .app, .other:       return nil
        }
    }
}
