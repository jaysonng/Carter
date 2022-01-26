//
//  URLInformation.swift
//
//
//  Created by Jayson Ng on 11/24/21.
//  based on Ocarina by Rens Verhoeven
//

#if !os(macOS)
import UIKit
#endif

import AVFoundation
import Kanna

/// A model containing information about a URL
public class URLInformation: Equatable {
    
    
    enum Properties {
        case type
        case siteName
        case originalURL
        case url
        case title
        case descriptionText
        case keywords
        case imageURL
        case imageSize
        case publishDate
        case section
        case faviconURL
        case appleTouchIconURL
        
    }
    
    /// The HTTPResponse from pulling the URL
    public var httpURLResponse: HTTPURLResponse?
    
    /// Type of URLInformation
    /// The type of the content behind the URL, this is determented (in order) by the `og:type` tag or mimetype
    public var type: URLInformationType
    public var defaultType: URLInformationType
    
    /// The contents of the og:site_name tag of the link.
    /// If og:site_name is not present, there is a fallback to the `<title>` html tag.
    public var siteName: String?
    
    /// The original URL the information was requested for.
    public let originalURL: URL
    
    /// The contents of the og:url tag of the link.
    /// If the Open Graph URL is not present, this will match the original or have the redirect URL if a redirect occured.
    public var url: URL
    
    /// The contents of the og:title tag of the link.
    /// If og:title is not present, there is a fallback to the `<title>` html tag.
    public var title: String?
    
    /// The contents of the author tag of the link.
    public var author: String?
    
    /// The contents of the og:description tag of the link.
    /// If og:description is not present, there is a fallback to the `<meta type="description">` html tag.
    public var descriptionText: String?
    
    /// The contents of the `keywords` tag of the link.
    /// need to see if we can get <script type="text/javascript"> data
    public var keywords: String?
    
    
    /// An URL to an image that was provided as the og:image tag.
    /// If no og:image tag is present, it falls back to the `<meta type="thumbnail">` html tag.
    public var imageURL: URL?
    
    /// The possible size of the image from the imageURL property. This size is parsed from the `og:image:width` and `og:image:height`.
    /// However since the implemenation of some websites doesn't follow the OGP standard, this size might be incorrect.
    public var imageSize: CGSize?
    
    /// Modified / Publication date of the article
    public var publishDate: String?
    
    /// The contents of the article:section tag of the link.
    public var section: String?
    
    
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
    public var twitterCard: TwitterCardInformation?
    
    
    
    
    // MARK: ---------------  Inits  ---------------
    /// Create a new instance of URLInformation with the given URL and title
    ///
    /// - Parameters:
    ///   - originalURL: The original URL the request was created with
    ///   - url: The URL which the information corresponds to. This might be an redirected url.
    ///   - html: The html of the page, this is used to search for (head) tags.
    ///   - response: The HTTPResponse for the page, this includes the status code.
    init(originalURL: URL, url: URL, html: HTMLDocument?, response: HTTPURLResponse? = nil, defaultType: URLInformationType = .website) {
        self.originalURL = originalURL
        self.url = url
        self.httpURLResponse = response
        self.defaultType = defaultType
        
        // Set defaults
        self.type = .website
        
        if let html = html {
            
            // We process the HTML data here:
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

    
    /// Processes the given HTMLDocument to get the needed URLInformation variables.
    /// - Parameter html: HTMLDocument to process
    private func processHTML(_ html: HTMLDocument) {
        
        let test = html.xpath("//meta[(@property|@name)=\"og:title\"]/@content")
        dump("test:======= \(test) ============")
        
        // MARK: ---------------  Type  ---------------
        /// og:type
        if let typeString = html.xpath("//meta[(@property|@name)=\"og:type\"]/@content").first?.text,
           let type       = URLInformationType.type(for: typeString) {
            self.type =  type
        } else {
            self.type =  defaultType
        }
        
        // MARK: ---------------  Site Name  ---------------
        /// og:site_name
        if let siteName = html.xpath("//meta[(@property|@name)=\"og:site_name\"]/@content").first?.text {
            self.siteName = siteName
        }
        
        // MARK: ---------------  URL  ---------------
        if let urlString = html.xpath("//meta[(@property|@name)=\"og:url\"]/@content").first?.text,
           let url = URL(string: urlString) {
            self.url = url
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
        
        // MARK: ---------------  Author  ---------------
        /// author
        if let author = html.xpath("//meta[(@property|@name)=\"author\"]/@content").first?.text {
            self.author = author
        }
        
        // MARK: ---------------  Description  ---------------
        /// og:description
        if let descriptionText = html.xpath("//meta[@property=\"og:description\"]/@content").first?.text {
            self.descriptionText = descriptionText
        } else if let descriptionText = html.xpath("//meta[(@property|@name)=\"description\"]/@content").first?.text {
            self.descriptionText = descriptionText
        }
        
        // MARK: ---------------  Keywords / Tags  ---------------
        /// keywords
        if let keywords = html.xpath("//meta[(@property|@name)=\"keywords\"]/@content").first?.text {
            self.keywords = keywords
        } else {
            // We'll go through all <script type="text/javascript">
            let scripts = html.xpath("//script[(@type)=\"text/javascript\"]").makeIterator()
            for node in scripts {
                
                // We're looking for "var keyword ="
                if let text = node.text, text.contains("var keyword =") {
                
                    let array = text.components(separatedBy: ";")
                    for item in array {
                        // We're assuming that the exact phrase "var keyword =" is used
                        // and that [ ] starts and ends the array.
                        if item.contains("var keyword ="),
                            let start = item.firstIndex(of: "["),
                            let end = item.firstIndex(of: "]")
                        {
                            
                            var string = String(item[start...end])
                                .trimmingCharacters(in: .whitespaces)
                            
                            // Remove the [ and ]
                            string.removeFirst()
                            string.removeLast()
                            
                            self.keywords = string
                        }
                    }
                }
                
            }
        }
        
        
        // MARK: ---------------  Image URL  ---------------
        if let imageURLString = html.xpath("//meta[(@property|@name)=\"og:image:secure_url\"]/@content").first?.text {
            self.imageURL = URL(string: imageURLString, relativeTo: url)
        }  else if let imageURLString = html.xpath("//meta[(@property|@name)=\"og:image:url\"]/@content").first?.text {
            self.imageURL = URL(string: imageURLString, relativeTo: url)
        }   else if let imageURLString = html.xpath("//meta[(@property|@name)=\"og:image\"]/@content").first?.text {
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
        
        // MARK: ---------------  Publish Date  ---------------
        /// Priority order to get publish date are the ff:
        /// - article:modified_time
        /// - article:published_time
        /// - og:updated_time
        /// - og:pubdate
        /// - pubdate
        if let publishedDateString = html.xpath("//meta[@property=\"article:modified_time\"]/@content ").first?.text {
            self.publishDate = publishedDateString
        } else if let publishedDateString = html.xpath("//meta[@property=\"article:published_time\"]/@content ").first?.text {
            self.publishDate = publishedDateString
        } else if let publishedDateString = html.xpath("//meta[@property=\"og:updated_time\"]/@content ").first?.text {
            self.publishDate = publishedDateString
        } else if let publishedDateString = html.xpath("//meta[@property=\"og:pubdate\"]/@content ").first?.text {
            self.publishDate = publishedDateString
        } else if let publishedDateString = html.xpath("//meta[@property=\"pubdate\"]/@content ").first?.text {
            self.publishDate = publishedDateString
        }
        
        // MARK: ---------------  Article Section Size  ---------------
        if let section = html.xpath("//meta[(@property|@name)=\"article:section\"]/@content").first?.text {
            self.section = section
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
        
        // MARK: ---------------  Twitter  ---------------
        self.twitterCard = TwitterCardInformation(html: html)
        
    }
}
