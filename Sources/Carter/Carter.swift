//
//  Carter.swift
//
//
//  Created by Jayson Ng on 11/24/21.
//
import Foundation
import Combine
import Kanna
import SwiftUI

public typealias InformationCompletionHandler = ((Result<URLInformation, CarterError>) -> ())
private typealias CarterURLSessionOutput = URLSession.DataTaskPublisher.Output

/// A class that scrapes OG or Meta data from a given URL
final public class Carter {
    
    public enum Mode {
        case basic
        case byURL
    }
    
    // MARK: ---------------  Properties  ---------------
    var url: URL
    var urlInformation: URLInformation?
    var defaultType: URLInformationType
    private var subscription: AnyCancellable?
    
    
    // MARK: ---------------  Init  ---------------
    // Carter MUST be initialized with a URL
    init(_ url: URL, defaultType: URLInformationType = .website) {
        self.url = url
        self.defaultType = defaultType
        print("defaultType is: ", defaultType)
    }
    
    // MARK: --------------- Methods ---------------
    /// The main method to pull information from a given URL
    /// - returns: URLInformation object created with data scraped from the URL
    public func getURLInformation(_ mode: Carter.Mode = .basic) async throws -> URLInformation? {
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<URLInformation, Error>) in
            
            switch mode {
            case .basic:
                getURLInformationBasic() { result in
                    switch result {
                    case .success(let urlInformation):
                        continuation.resume(returning: urlInformation)
                    case .failure(let error):
                        print("Error getting URLInformation with HTTPResponse", error.localizedDescription)
                        continuation.resume(throwing: CarterError.failedToGetURLInformation)
                    }
                }
                
                // Using .byURL has downsides. It currently does not handle wesites with wrong charset.
            case .byURL:
                getURLInformationByURL(url) { result in
                    switch result {
                    case .success(let urlInformation):
                        continuation.resume(returning: urlInformation)
                    case .failure(let error):
                        //                        completion(.failure(CarterError.failedToGetURLInformation))
                        print("Error getting URLInformation without HTTPResponse", error.localizedDescription)
                        continuation.resume(throwing: CarterError.failedToGetURLInformation)
                    }
                    
                }
            }
            
        }
    }
    
    /// Called by default, with HTTPResponse bound to URLInformation object
    private func getURLInformationBasic(completion: @escaping InformationCompletionHandler) {
        
        subscription = urlSessionPublisher(for: url)
            .sink(receiveCompletion: { sinkCompletion in
                print("Sink received completion: \(sinkCompletion)")
                switch sinkCompletion {
                case .failure(let error):
                    print("Error:", error)
                    completion(.failure(CarterError.failedToGetURLInformation))
                case .finished:
                    print("----------Done pulling URL Data----------")
                }
                
            }, receiveValue: { [self] data, response in
                //print("Retrieved data of size \(data.count), response = \(response)")
                let response = response as! HTTPURLResponse
                if response.statusCode < 200 || response.statusCode >= 300 {
                    //We don't have a valid response, we end it here! If we don't have a response at all, we will just continue
                    completion(.failure(CarterError.failedToGetURLInformation))
                } else {
                    Task {
                        do {
                            var html: HTMLDocument? = nil
                            html = try await HTMLHelper(html: data, encoding: .utf8)
                            self.urlInformation = URLInformation(originalURL: self.url, url: self.url, html: html, response: response, defaultType: defaultType)
                            
                            if let urlInfo = urlInformation {
                                dump(self.urlInformation)
                                completion(.success(urlInfo))
                            } else {
                                completion(.failure(CarterError.failedToGetURLInformation))
                            }
                        } catch {
                            completion(.failure(CarterError.failedToGetURLInformation))
                        }
                    }
                    
                    
                    
                }
            })
    }
    
    /// Get URL information via Kanna's HTML(url: encoding)
    /// From testing, this is more unreliable and may fail based on the developer of the website.
    /// - Returns: URLInformation object without HTTPResponse.
    private func getURLInformationByURL(_ url: URL, completion: @escaping InformationCompletionHandler) {
        var html: HTMLDocument? = nil
        do {
            html = try HTML(url: url, encoding: .utf8)
            self.urlInformation = URLInformation(originalURL: self.url, url: self.url, html: html)
            
            if let urlInfo = urlInformation {
                dump(self.urlInformation)
                completion(.success(urlInfo))
            } else {
                completion(.failure(CarterError.failedToGetURLInformation))
            }
            
        } catch {
            print(error.localizedDescription)
            completion(.failure(CarterError.failedToGetURLInformation))
        }
    }
}


// MARK: ---------------  Helpers  ---------------
extension Carter {
    
    /// URLSession Publisher to receive URLSession.DataTaskPublisher.Output
    private func urlSessionPublisher(for url: URL) -> AnyPublisher<CarterURLSessionOutput, Error> {
        
        let apiQueue = DispatchQueue(label: "API", qos: .default, attributes: .concurrent)
        
        return URLSession.shared
            .dataTaskPublisher(for: url)
            .receive(on: apiQueue)
            .handleEvents(receiveSubscription: { _ in
                print("Network request will start")
            }, receiveOutput: { _ in
                print("Network request data received")
            }, receiveCancel: {
                print("Network request cancelled")
            })
            .tryMap { output in
                print("data is:", output.data)
                guard let response = output.response as? HTTPURLResponse, response.statusCode == 200 else {
                    // TODO: Parse statusCode and get a better throw information
                    throw CarterError.failedToGetURLInformation
                }
                return output
            }
            .eraseToAnyPublisher()
    }
    
    /// Private HTMLHelper to check if we properly receive an ecoded html as a String
    private func HTMLHelper(html: Data, encoding: String.Encoding) async throws -> HTMLDocument? {
        var htmlStr = ""
        
        // 1. Get the string data
        if let str = String(data: html, encoding: encoding) {
            htmlStr = str
            
            // 2. We try .ascii as a backup if encoding fails.
        } else if let str = String(data: html, encoding: .ascii) {
            htmlStr = str
        } else {
            throw CarterError.failedToGetURLInformation
        }
        
        // 2. Call Kanna's HTML parser with encoding falling back to utf8 encoding if it fails.
        do {
            do {
                let html = try HTML(html: htmlStr, encoding: encoding)
                return html
            } catch {
                do {
                    // Last resort
                    let html = try HTML(html: htmlStr, encoding: .utf8)
                    return html
                } catch {
                    throw CarterError.failedToGetURLInformation
                }
            }
            
        } catch {
            throw CarterError.failedToGetURLInformation
        }
        
    }
    
    
    subscript(type: URLInformationType) -> Carter {
        return Carter(url, defaultType: type)
    }
}


// MARK: ---------------  Extensions  ---------------
extension URL {
    
    /// The Carter object for this URL.
    /// Can be used to request information for this URL
    /// - returns: Carter Object
    public var carter: Carter {
        return Carter(self)
    }
    
    /// If you need to set the default type away from .website, you can set it by calling carter(.type)
    /// - returns: Carter Object
    public func carter(_ type: URLInformationType = .website) -> Carter {
        return Carter(self, defaultType: type)
    }
}
