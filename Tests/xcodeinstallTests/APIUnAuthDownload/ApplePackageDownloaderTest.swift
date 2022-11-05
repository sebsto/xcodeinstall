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
        let apd = ApplePackageDownloader()

        //
        (env.api as! MockedNetworkAPI).nextHeader = ["Set-Cookie" : "ADCDownloadAuth=AuthCookieValue;Version=1;Comment=;Domain=apple.com;Path=/;Max-Age=108000;HttpOnly;Expires=Sat, 22 Oct 2032 04:54:51 GMT"]

        // when
        do {
            let authCookie = try await apd.authenticationCookie(for: package)
            
            // then
            XCTAssertNotNil(authCookie)
            XCTAssertEqual(authCookie.name, "ADCDownloadAuth") //validate parsing
            XCTAssertEqual(authCookie.value, "AuthCookieValue") //value hard coded in the mock
        } catch {
            XCTAssert(false, "Error : \(error)")
        }
        
    }
    
    func testAvailableDownloads() async {
        
        // given
        
        let availableDownloads = try? loadAvailableDownloadFromTestFile()
        (env.api as! MockedNetworkAPI).nextData = try! JSONEncoder().encode(availableDownloads?.list)

        // when
        do {
            let availableDownloadList = try await env.downloader.listAvailableDownloads()
            
            // then
            XCTAssertNotNil(availableDownloadList.list)
            XCTAssertEqual(availableDownloadList.count, 979)
        } catch {
            XCTAssert(false, "Error : \(error)")
        }

    }
    
    func testDownload() async {

        // given
        let delegate = AppleDownloadDelegate()
        
        let package = Package(download: .xCode, version: "14")
        let apd = ApplePackageDownloader()

        let dst = URL(fileURLWithPath: "/tmp/dummy")
        
        // this will be consumed by the Authentication URL call 
        (env.api as! MockedNetworkAPI).nextHeader = ["Set-Cookie" : "ADCDownloadAuth=AuthCookieValue;Version=1;Comment=;Domain=apple.com;Path=/;Max-Age=108000;HttpOnly;Expires=Sat, 22 Oct 2032 04:54:51 GMT"]

        Task {

            // Delay the task by 1 second:
            try await Task.sleep(nanoseconds: 1_000_000_000)
                
            XCTAssertNotNil(delegate.callback)
            delegate.callback!(.success(dst))
        }
                
        // when
        let file = try? await apd.download(package, with: delegate)

        // then
        XCTAssertNotNil(file)
        XCTAssertEqual(dst.absoluteURL, file?.absoluteURL)

    }


}
