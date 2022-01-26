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
        case manilabulletin =
            "https://mb.com.ph/2021/11/27/ph-logs-below-1k-covid-19-cases-for-3rd-straight-day/"
        
        case cnnPH = "https://cnnphilippines.com/news/2021/11/27/Govt-mulls-possible-expansion-Omicron-travel-ban.html"
        
        case badUrl =
                "https://www.gmanetwork.com/news/balitambayan/chikamuna/81223/bts-nag-perntersection-sa-l-a/story/?just_in"
        
    }
    
    let url = URL(string: URLs.inquirer.rawValue)!
    
    var subscription: AnyCancellable?
    
    var urlInformation: URLInformation?
    
    private let apiQueue = DispatchQueue(label: "API",
                                         qos: .default,
                                         attributes: .concurrent)
    
    func testBasic() async throws {
        do {
            let urlInfo = try await url.carter.getURLInformation()
//            print("urlInfo: ", urlInfo?.title)
        } catch let error as CarterError {
            print(error.description)
            XCTAssertNil(error)
        }
    }
    
    func testByURL() async throws {
        do {
            let urlInfo = try await url.carter.getURLInformation(.byURL)
        } catch let error as CarterError {
            print(error.description)
            XCTAssertNil(error)
        }
    }
    
    func testPhilStar() async throws {
        let url2 = URL(string: URLs.philStar.rawValue)!
        do {
            //let urlInfo = try await url2.carter.getURLInformation()
            let urlInfo = try await url2.carter(.article).getURLInformation()
        } catch let error as CarterError {
            print(error.description)
            XCTAssertNil(error)
        }
    }
    
    // This test will fail as philstar website has bad encoding.
    // as of 11/28/2021
    func testPhilStarByURL() async throws {
        let url2 = URL(string: URLs.philStar.rawValue)!
        do {
            let urlInfo = try await url2.carter[.article].getURLInformation()
        } catch let error as CarterError {
            print(error.description)
            XCTAssertNotNil(error) // XCTAssertNotNil
        }
    }
    
}

