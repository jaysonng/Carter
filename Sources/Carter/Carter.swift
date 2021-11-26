//
//  Carter.swift
//
//
//  Created by Jayson Ng on 11/24/21.
//
import Foundation
import Combine
import Kanna

public typealias InformationCompletionHandler = ((Result<URLInformation, CarterError>) -> ())
private typealias CarterURLSessionOutput = URLSession.DataTaskPublisher.Output

final public class Carter {
    
    
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
    /// - returns Result<URLInformation, CarterError>
    func getUrlInformation(completion: @escaping InformationCompletionHandler) throws {
        
        subscription = urlSessionPublisher(for: url)
            .sink(receiveCompletion: { completion in
                print("Sink received completion: \(completion)")
                switch completion {
                case .failure(let error):
                    print("Error:", error)
                case .finished:
                    print("Done pulling URL Data")
                }
                
            }, receiveValue: { [self] data, response in
                // print("Retrieved data of size \(data.count), response = \(response)")
                let response = response as! HTTPURLResponse
                if response.statusCode < 200 || response.statusCode >= 300 {
                    //We don't have a valid response, we end it here! If we don't have a response at all, we will just continue
                    print("failed to get URL Information")
                    completion(.failure(CarterError.failedToGetURLInformation))
                } else {
                    var html: HTMLDocument? = nil
                    html = try? HTML(html: data, encoding: .utf8)
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
                guard let response = output.response as? HTTPURLResponse, response.statusCode == 200 else {
                    // TODO: Parse statusCode and get a better throw information
                    throw CarterError.failedToGetURLInformation
                }
                return output
            }
            .eraseToAnyPublisher()
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


