//
//  ApplePackageDownloaderTest.swift
//  
//
//  Created by Stormacq, Sebastien on 22/10/2022.
//

import XCTest
@testable import xcodeinstall

//func fixture(for url: URL, fileURL: URL? = nil, statusCode: Int, headers: [String: String]) -> (Data, URLResponse) {
//
//    let data = fileURL != nil ? try! Data(contentsOf: fileURL!) : Data()
//    let response = HTTPURLResponse(url: url, statusCode: statusCode, httpVersion: "HTTP/1.1", headerFields: headers)!
//
//    return (data, response)
//}

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

        //
        NetworkAPI.nextHeader = ["Set-Cookie" : "ADCDownloadAuth=AuthCookieValue;Version=1;Comment=;Domain=apple.com;Path=/;Max-Age=108000;HttpOnly;Expires=Sat, 22 Oct 2032 04:54:51 GMT"]

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
    
    func testAvailableDownloads() async {
        
        // given
        
        // https://stackoverflow.com/questions/47177036/use-resources-in-unit-tests-with-swift-package-manager
        let filePath = Bundle.module.path(forResource: "available-downloads", ofType: "json")!
        let fileURL = URL(fileURLWithPath: filePath)
        NetworkAPI.nextData = try! Data(contentsOf: fileURL)

        // when
        do {
            let list = try await ApplePackageDownloader.listAvailableDownloads()
            
            // then
            XCTAssertNotNil(list)
            XCTAssertEqual(list.count, 401)
        } catch {
            XCTAssert(false, "Error : \(error)")
        }

    }
    
    func testDownload() async {

        // given
        let delegate = AppleDownloadDelegate()
        
        let package = Package(download: .xCode, version: "14")
        let apd = ApplePackageDownloader(package: package)

        let dst = URL(fileURLWithPath: "/tmp/dummy")

        Task {
            // Delay the task by 0.5 second:
            try await Task.sleep(nanoseconds: 500_000_000)
                
            XCTAssertNotNil(delegate.callback)
            delegate.callback!(.success(dst))
        }
                
        // when
        let file = try? await apd.download(to: dst, with: delegate)
        
        // then
        XCTAssertNotNil(file)
        XCTAssertEqual(dst.absoluteURL, file!.absoluteURL)

    }


}
