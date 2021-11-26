//import Foundation
//import XCTest
//
//@testable import Carter
//
//class InformationFetchingTests: XCTestCase {
//    let url = URL(string: "https://www.nytimes.com/interactive/2017/04/02/technology/uber-drivers-psychological-tricks.html")
//    
//    @available(iOS 15.0.0, *)
//    func testURLInformationFetchingWithOGP() async {
//        guard let url = url else { XCTFail("Invalid URL"); return }
//        do {
//            let urlInformation = try await url.carter.fetchURLInformation()
//            if let urlInformation = urlInformation {
//                dump("UrlInfo: \(urlInformation)")
//                XCTAssertNotNil(urlInformation, "Information is missing")
//                XCTAssert(urlInformation.type == .article, "The link should be of type article.")
//                XCTAssert(urlInformation.title?.count ?? 0 > 0, "The article should have a title of at least 1 character.")
//                XCTAssert(urlInformation.descriptionText?.count ?? 0 > 0, "The article should have a description of at least 1 character.")
//                XCTAssert(urlInformation.imageURL != nil, "The article should have an image.")
//                XCTAssert(urlInformation.faviconURL != nil, "The link should have a favicon.")
//                XCTAssert(urlInformation.appleTouchIconURL != nil, "The link should have a apple touch icon.")
//            } else {
//                XCTAssertNotNil(urlInformation)
//            }
//            
//        } catch {
//            dump("error: \(error.localizedDescription)")
//            XCTAssertNil(error, "An error occured fetching the information")
//        }
//
//    }
//}
//    
//    
////    func testInformationFetchingWithOGP()  {
////        guard let url = URL(string: "https://www.nytimes.com/interactive/2017/04/02/technology/uber-drivers-psychological-tricks.html") else {
////            XCTFail("Invalid URL")
////            return
////        }
////        
//////        do {
////            url.fetchInformation { information in
////                XCTAssertNotNil(information, "Information is missing")
////                XCTAssert(information?.type == .article, "The link should be of type article.")
////                XCTAssert(information?.title?.count ?? 0 > 0, "The article should have a title of at least 1 character.")
////                XCTAssert(information?.descriptionText?.count ?? 0 > 0, "The article should have a description of at least 1 character.")
////                XCTAssert(information?.imageURL != nil, "The article should have an image.")
////                XCTAssert(information?.faviconURL != nil, "The link should have a favicon.")
////                XCTAssert(information?.appleTouchIconURL != nil, "The link should have a apple touch icon.")
////            
//////        } catch {
//////            XCTAssertNil(error, "An error occured fetching the information")
//////        }
//////
////            }
////    }
//
//
