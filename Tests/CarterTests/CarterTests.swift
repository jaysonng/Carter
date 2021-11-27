import Foundation
import Combine
import Kanna
import XCTest
@testable import Carter

@available(iOS 15.0, *)
final class CarterTests: XCTestCase {
    
    enum URLs: String {
        case gmanetwork = "https://www.gmanetwork.com/news/balitambayan/chikamuna/812236/bts-nag-perform-ng-butter-habang-traffic-sa-intersection-sa-l-a/story/?just_in"
        case inquirer = "https://newsinfo.inquirer.net/1520253/concerned-by-new-variant-asian-countries-move-to-tighten-covid-measures?utm_source=gallery&utm_medium=direct"
        case philStar = "https://www.philstar.com/headlines/2021/11/26/2143993/philippines-loosens-borders-coronavirus-cases-continue-drop"
        //case manilabulletin
        case badUrl =
                "https://www.gmanetwork.com/news/balitambayan/chikamuna/81223/bts-nag-perntersection-sa-l-a/story/?just_in"
        
    }
    
    let url = URL(string: URLs.badUrl.rawValue)!
    
    var subscription: AnyCancellable?
    
    var urlInformation: URLInformation?
    
    private let apiQueue = DispatchQueue(label: "API",
                                         qos: .default,
                                         attributes: .concurrent)
    
    func test() async throws {
        do {
            let urlInfo = try await url.carter.getURLInformation()
            print("urlInfo: ", urlInfo?.title)
        } catch let error as CarterError {
            print(error.description)
        }
    }
    
    func testWithoutHTTPResponse() async throws {
        do {
            let urlInfo = try await url.carter.getURLInformation(.withoutHTTPResponse)
            print("urlInfo: ", urlInfo?.title)
        } catch let error as CarterError {
            print(error.description)
        }
    }
    
    func testPhilStarEncodingAscii() async throws {
        let url2 = URL(string: URLs.philStar.rawValue)!
        do {
            let urlInfo = try await url2.carter.getURLInformation()
            print("urlInfo: ", urlInfo?.title)
        } catch let error as CarterError {
            print(error.description)
        }
    }
    
}

