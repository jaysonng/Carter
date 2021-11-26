import Foundation
import Combine
import Kanna
import XCTest
@testable import Carter

@available(iOS 15.0, *)
final class CarterTests: XCTestCase {
    let url = URL(string: "https://www.gmanetwork.com/news/balitambayan/chikamuna/812236/bts-nag-perform-ng-butter-habang-traffic-sa-intersection-sa-l-a/story/?just_in")!
    let urlBad = URL(string: "https://www.gmanetwork.com/news/balitambayan/chikamuna/81223/bts-nag-perntersection-sa-l-a/story/?just_in")!

    var subscription: AnyCancellable?
    
    var urlInformation: URLInformation?
    
    private let apiQueue = DispatchQueue(label: "API",
                                         qos: .default,
                                         attributes: .concurrent)
    
    func test() throws {
        let exp = expectation(description: "Loading URL")
        try url.carter.getUrlInformation() { result in
            switch result {
            case .success(let urlInformation):
                dump(urlInformation)
                XCTAssertNotNil(urlInformation)
            case .failure(let error):
                print("Error", error.description)
            }
            exp.fulfill()
        }
    
        waitForExpectations(timeout: 1)

    }
    
   
}

