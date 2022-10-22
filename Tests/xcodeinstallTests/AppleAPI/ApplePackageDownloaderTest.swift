//
//  ApplePackageDownloaderTest.swift
//  
//
//  Created by Stormacq, Sebastien on 22/10/2022.
//

import XCTest
@testable import xcodeinstall

final class ApplePackageDownloaderTest: XCTestCase {

    override func setUpWithError() throws {
        
        //mock our environment
        env = Environment.mock
    }

    override func tearDownWithError() throws {
    }

    func testGetAuthenticationCookie() async {
        
        // given
        let package = Package(download: .xCode, version: "14")
        let apd = ApplePackageDownloader(package: package)
        
        // when
        do {
            let authCookie = try await apd.authenticationCookie()
            
            // then
            XCTAssertNotNil(authCookie)
            XCTAssertEqual(authCookie, "AuthCookieValue") //value hard coded in the mock
        } catch {
            XCTAssert(false, "Error : \(error)")
        }
        
    }
}
