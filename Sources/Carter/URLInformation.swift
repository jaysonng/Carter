//
//  URLInformation.swift
//
//
//  Created by Jayson Ng on 11/24/21.
//  based on Ocarina by Rens Verhoeven
//

import UIKit
import AVFoundation
import Kanna


/// A model containing information about a URL
public class URLInformation: Equatable {
    
    enum Properties {
        case originalURL
        case url
        case title
        case descriptionText
        case imageURL
        case imageSize
        case faviconURL
        case appleTouchIconURL
        case type
        case siteName
        case publishDate
        case keywords
    }
    
    /// The original URL the information was requested for.
    public let originalURL: URL
    
    /// The contents of the og:url tag of the link.
    /// If the Open Graph URL is not present, this will match the original or have the redirect URL if a redirect occured.
    public var url: URL
    
    /// The contents of the og:title tag of the link.
    /// If og:title is not present, there is a fallback to the `<title>` html tag.
    //    private var _title: String?
    public var title: String?
    //    { _title }
    
    /// The contents of the og:description tag of the link.
    /// If og:description is not present, there is a fallback to the `<meta type="description">` html tag.
    public var descriptionText: String?
    
    /// An URL to an image that was provided as the og:image tag.
    /// If no og:image tag is present, it falls back to the `<meta type="thumbnail">` html tag.
    public var imageURL: URL?
    
    /// The possible size of the image from the imageURL property. This size is parsed from the `og:image:width` and `og:image:height`.
    /// However since the implemenation of some websites doesn't follow the OGP standard, this size might be incorrect.
    public var imageSize: CGSize?
    
    /// An URL to the Favicon image that was provided by the icon link tag.
    /// Domains may also have a faveicon at `http://DOMAIN.TLD/favicon.ico`. However this property only checks for the tag in the head of a page.
    /// You may still do a HEAD request to see if the icon is avaible at that URL.
    public var faviconURL: URL?
    
    /// An URL to the Apple Touch Icon (Homescreen icon) that was provided by the apple-touch-icon tag.
    /// Domains may also have a icon at `http://DOMAIN.TLD/apple-touch-icon.png`. However this property only checks for the tag in the head of a page.
    /// You may still do a HEAD request to see if the icon is avaible at that URL.
    /// This property ignores additional sizes.
    public var appleTouchIconURL: URL?
    
    /// Twitter card information, if this is available. Can be used as a fallback in case some tags are missing.
    //    public var twitterCard: TwitterCardInformation?
    
    /// The type of the content behind the URL, this is determented (in order) by the `og:type` tag or mimetype
    //private var _type: URLInformationType
    public var type: URLInformationType
    //    { _type }
    
    
    
    /// The contents of the og:site_name tag of the link.
    /// If og:site_name is not present, there is a fallback to the `<title>` html tag.
    public var siteName: String?
    
    /// The contents of the og:pubdate tag of the link.
    /// If og:pubdate is not present, there is a fallback to the `<meta type="pubdate">` html tag and `<meta property="article:published_time">` html tag.
    public var publishDate: String?
    
    /// The contents of the `keywords` tag of the link.
    /// need to see if we can get <script type="text/javascript"> data
    public var keywords: String?
    
    /// The HTTPResponse from pulling the URL
    public var httpURLResponse: HTTPURLResponse?
    
    
    // MARK: ---------------  Inits  ---------------
    /// Create a new instance of URLInformation with the given URL and title
    ///
    /// - Parameters:
    ///   - originalURL: The original URL the request was created with
    ///   - url: The URL which the information corresponds to. This might be an redirected url.
    ///   - html: The html of the page, this is used to search for (head) tags.
    ///   - response: The HTTPResponse for the page, this includes the status code.
    init(originalURL: URL, url: URL, html: HTMLDocument?, response: HTTPURLResponse? = nil) {
        self.originalURL = originalURL
        self.url = url
        self.httpURLResponse = response
        
        // Set defaults
        self.type = .website
        
        if let html = html {
            
            processHTML(html)
            
        } else {
            
            //If the HTML is not available, we only determine the type based on the mime type
            if let mimeType = response?.mimeType {
                self.type = URLInformationType.type(forMimeType: mimeType)
            }
            self.title = nil
            self.descriptionText = nil
        }
    }
    
    public static func ==(lhs: URLInformation, rhs: URLInformation) -> Bool {
        return lhs.url == rhs.url
    }
    
}


extension URLInformation {
    
    func processHTML(_ html: HTMLDocument) {
        
        let test = html.xpath("//meta[(@property|@name)=\"og:title\"]/@content")
        dump("test:======= \(test) ============")
        
        // MARK: ---------------  Type  ---------------
        /// og:type
        if let typeString = html.xpath("//meta[(@property|@name)=\"og:type\"]/@content").first?.text,
           let type       = URLInformationType.type(for: typeString) {
            self.type =  type
        } else {
            self.type =  .website
        }
        
        
        // MARK: ---------------  Title  ---------------
        /// og:title
        if let title = html.xpath("//meta[(@property|@name)=\"og:title\"]/@content").first?.text {
            self.title = title
        } else if let title = html.title {
            self.title = title
        } else {
            self.title = nil
        }
        
        
        // MARK: ---------------  Description  ---------------
        /// og:description
        if let descriptionText = html.xpath("//meta[@property=\"og:description\"]/@content").first?.text {
            self.descriptionText = descriptionText
        } else if let descriptionText = html.xpath("//meta[(@property|@name)=\"description\"]/@content").first?.text {
            self.descriptionText = descriptionText
        }
        
        
        // MARK: ---------------  URL  ---------------
        if let urlString = html.xpath("//meta[(@property|@name)=\"og:url\"]/@content").first?.text,
           let url = URL(string: urlString) {
            self.url = url
        }
        
        // MARK: ---------------  Image URL  ---------------
        if let imageURLString = html.xpath("//meta[(@property|@name)=\"og:image:secure_url\"]/@content").first?.text {
            self.imageURL = URL(string: imageURLString, relativeTo: url)
        } else if let imageURLString = html.xpath("//meta[(@property|@name)=\"og:image\"]/@content").first?.text {
            self.imageURL = URL(string: imageURLString, relativeTo: url)
        } else if let imageURLString = html.xpath("//meta[(@property|@name)=\"thumbnail\"]/@content").first?.text {
            self.imageURL = URL(string: imageURLString, relativeTo: url)
        }
        
        // MARK: ---------------  Image Size  ---------------
        if let imageWidthString = html.xpath("//meta[(@property|@name)=\"og:image:width\"]/@content").first?.text,
           let imageHeightString = html.xpath("//meta[(@property|@name)=\"og:image:height\"]/@content").first?.text {
            let imageWidth: CGFloat = CGFloat(Float(imageWidthString) ?? 0)
            let imageHeight: CGFloat = CGFloat(Float(imageHeightString) ?? 0)
            if imageWidth > 0 && imageHeight > 0 {
                self.imageSize = CGSize(width: imageWidth, height: imageHeight)
            }
        }
        
        // MARK: ---------------  Favicon  ---------------
        if let faviconURLString = html.xpath("/html/head/link[@rel=\"shortcut icon\"]/@href").first?.text {
            self.faviconURL = URL(string: faviconURLString, relativeTo: url)
        } else if let faviconURLString = html.xpath("/html/head/link[@rel=\"icon\"]/@href").first?.text {
            self.faviconURL = URL(string: faviconURLString, relativeTo: url)
        }
        
        // MARK: ---------------  Apple Touch Icon  ---------------
        if let appleTouchIconURLString = html.xpath("/html/head/link[@rel=\"apple-touch-icon\" and not(@sizes)]/@href").first?.text {
            self.appleTouchIconURL = URL(string: appleTouchIconURLString, relativeTo: url)
        } else if let appleTouchIconURLString = html.xpath("/html/head/link[@rel=\"apple-touch-icon\" and @sizes=\"180x180\"]/@href").first?.text {
            self.appleTouchIconURL = URL(string: appleTouchIconURLString, relativeTo: url)
        } else if let appleTouchIconURLString = html.xpath("/html/head/link[@rel=\"apple-touch-icon-precomposed\" and not(@sizes)]/@href").first?.text {
            self.appleTouchIconURL = URL(string: appleTouchIconURLString, relativeTo: url)
        }
        
        //            self.twitterCard = TwitterCardInformation(html: html)
        
        // MARK: ---------------  Publish Date  ---------------
        if let publishedDateString = html.xpath("//meta[@property=\"article:published_time\"]/@content ").first?.text {
            self.publishDate = publishedDateString
        } else if let publishedDateString = html.xpath("//meta[@property=\"og:pubdate\"]/@content ").first?.text {
            self.publishDate = publishedDateString
        } else if let publishedDateString = html.xpath("//meta[@property=\"pubdate\"]/@content ").first?.text {
            self.publishDate = publishedDateString
        }
    }
}
