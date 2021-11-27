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

final public class Carter {
    
    public enum Mode {
        case withHTTPResponse
        case withoutHTTPResponse
    }
    
    // MARK: ---------------  Properties  ---------------
    var url: URL
    var urlInformation: URLInformation?
    private var subscription: AnyCancellable?
    
    
    // MARK: ---------------  Init  ---------------
    /// Carter must be initialized with a URL
    init(_ url: URL) {
        self.url = url
    }
    
    // MARK: --------------- Methods ---------------
    /// The main method to pull information from a given URL
    /// - returns URLInformation object from url
    public func getURLInformation(_ mode: Carter.Mode = .withHTTPResponse) async throws -> URLInformation? {
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<URLInformation, Error>) in
            
            switch mode {
            case .withHTTPResponse:
                getURLInformationWithHTTPResponse() { result in
                    switch result {
                    case .success(let urlInformation):
                        continuation.resume(returning: urlInformation)
                    case .failure(let error):
                        //                        completion(.failure(CarterError.failedToGetURLInformation))
                        print("Error getting URLInformation with HTTPResponse", error.localizedDescription)
                        continuation.resume(throwing: CarterError.failedToGetURLInformation)
                    }
                }
                
            case .withoutHTTPResponse:
                getURLInformationWithoutHTTPResponse() { result in
                    
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
    
    /// Called by default, with HTTPResponse bound to URLInformation object
    private func getURLInformationWithHTTPResponse(completion: @escaping InformationCompletionHandler) {
        
        subscription = urlSessionPublisher(for: url)
            .sink(receiveCompletion: { sinkCompletion in
                print("Sink received completion: \(sinkCompletion)")
                switch sinkCompletion {
                case .failure(let error):
                    print("Error:", error)
                    completion(.failure(CarterError.failedToGetURLInformation))
                case .finished:
                    print("Done pulling URL Data")
                }
                
            }, receiveValue: { [self] data, response in
                //print("Retrieved data of size \(data.count), response = \(response)")
                let response = response as! HTTPURLResponse
                if response.statusCode < 200 || response.statusCode >= 300 {
                    //We don't have a valid response, we end it here! If we don't have a response at all, we will just continue
                    completion(.failure(CarterError.failedToGetURLInformation))
                } else {
                    var html: HTMLDocument? = nil
                    do {
                        html = try HTML(html: data, encoding: .utf8)
                    } catch {
                        completion(.failure(CarterError.failedToGetURLInformation))
                    }
                    
                    self.urlInformation = URLInformation(originalURL: self.url, url: self.url, html: html, response: response)
                    
                    if let urlInfo = urlInformation {
                        dump(self.urlInformation)
                        completion(.success(urlInfo))
                    } else {
                        completion(.failure(CarterError.failedToGetURLInformation))
                    }
                    
                }
            })
    }
    
    
    /// Returns URLInformation withoutHTTPResponse.
    private func getURLInformationWithoutHTTPResponse(completion: @escaping InformationCompletionHandler) {
        var html: HTMLDocument? = nil
        do {
            html = try HTML(url: url, encoding: .utf8)
            self.urlInformation = URLInformation(originalURL: self.url, url: self.url, html: html)
            
            if let urlInfo = urlInformation {
                dump(self.urlInformation)
                completion(.success(urlInfo))
            } else {
                completion(.failure(CarterError.failedToGetURLInformation))
                //throw CarterError.failedToGetURLInformation
            }
            
        } catch {
            print(error.localizedDescription)
            completion(.failure(CarterError.failedToGetURLInformation))
            //throw CarterError.failedToGetURLInformation
        }
    }
}

// MARK: ---------------  Extensions  ---------------
extension URL {
    /// The Carter object for this URL.
    /// Can be used to request information for this URL
    public var carter: Carter {
        return Carter(self)
    }
}
