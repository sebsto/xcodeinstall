//
//  AppleURLTest.swift
//  
//
//  Created by Stormacq, Sebastien on 22/10/2022.
//

import XCTest
@testable import xcodeinstall

final class AppleURLTest: XCTestCase {
    
    override func setUpWithError() throws {
    }
    
    override func tearDownWithError() throws {
    }
    
    func testURLAuthentication() throws {
        
        // given
        let package = Package(download: .xCode, version: "14.0.1")
        
        // when
        let url = URL.appleAuthenticationUrl(package: package)
        
        // then
        let expectedResult = "https://developerservices2.apple.com/services/download?path=/Developer_Tools/Xcode_14.0.1/Xcode_14.0.1.xip"
        XCTAssertEqual(expectedResult, url.description)
    }

    func testURLDownload() throws {
        
        // given
        let package = Package(download: .xCode, version: "14.0.1")
        
        // when
        let url = URL.appleDownloadUrl(package: package)
        
        // then
        let expectedResult = "https://download.developer.apple.com/Developer_Tools/Xcode_14.0.1/Xcode_14.0.1.xip"
        XCTAssertEqual(expectedResult, url.description)
    }
    
    func testRequestAuthentication() {
        
        // given
        let package = Package(download: .xCode, version: "14.0.1")
        
        // when
        let request = URLRequest.appleAuthenticationCookie(for: package)
        
        // then
        let expectedResult = "https://developerservices2.apple.com/services/download?path=/Developer_Tools/Xcode_14.0.1/Xcode_14.0.1.xip"
        XCTAssertEqual(expectedResult, request.url?.description)
    }
    
    func testRequestDownload() {
        
        // given
        let package = Package(download: .xCode, version: "14.0.1")
        
        // when
        let request = URLRequest.appleDownloadURL(for: package)
        
        // then
        let expectedResult = "https://download.developer.apple.com/Developer_Tools/Xcode_14.0.1/Xcode_14.0.1.xip"
        XCTAssertEqual(expectedResult, request.url?.description)
    }

    func testResponseCookie() {
        
        // given
        let package = Package(download: .xCode, version: "14.0.1")
        let request = URLRequest.appleAuthenticationCookie(for: package)

        let cookieValue = "AuthCookieValue"
        let headers = ["Set-Cookie" : "ADCDownloadAuth=\(cookieValue);Version=1;Comment=;Domain=apple.com;Path=/;Max-Age=108000;HttpOnly;Expires=Sat, 22 Oct 2032 04:54:51 GMT"]
        let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: headers)!

        // when
        let cookie = try? response.appleAuthCookie()
        
        // then
        XCTAssertNotNil(cookie)
        XCTAssertEqual(cookieValue, cookie)
    }
    
    func testResponseCookieError() {
        
        // given
        
        let package = Package(download: .xCode, version: "14.0.1")
        let request = URLRequest.appleAuthenticationCookie(for: package)

        let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: nil)!

        // when
        XCTAssertThrowsError(try response.appleAuthCookie(), "error thrown") { error in
            
            // then
            XCTAssertEqual(error as! AppleAPIError, AppleAPIError.noCookie)
        }
    }
    
    func testRequestAvailableDOwnloads() {
        
        // given
        
        // when
        let request = URLRequest.availableDowloads()
        
        // then
        let expectedResult = "https://raw.githubusercontent.com/sebsto/xcodeinstall/main/available-downloads.json"
        XCTAssertEqual(expectedResult, request.url?.description)

        
    }

}
