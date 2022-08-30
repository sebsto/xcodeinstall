//
//  ListTest.swift
//  xcodeinstallTests
//
//  Created by Stormacq, Sebastien on 22/08/2022.
//

import XCTest
@testable import xcodeinstall

class ListTest: NetworkAgentTestCase {

    func testListNoForce() async throws {
        
        // given
        let ad = getAppleDownloader()
        
        // when
        let result : [DownloadList.Download] = try await ad.list(force: false)
        
        // then
        XCTAssertNotNil(result)
        XCTAssert(result.count > 0)
    }

    func testListForce() async throws {
        
        do {
            
            // given
            let (listData, urlResponse) = try prepareResponse(withDataFile: "Download List.json")
            self.session.nextData       = listData
            self.session.nextResponse   = urlResponse

            // when
            let ad = getAppleDownloader()
            let result = try await ad.list(force: true)

            // then
            XCTAssertNotNil(result)
            XCTAssert(result.count == 953)

        } catch let error as DownloadError {

            XCTAssert(false, "Exception thrown : \(error)")

        } catch {
            XCTAssert(false, "Unexpected exception thrown")
        }

    }
    
    func testListForceParsingError() async throws {
        
        do {
            
            // given
            let (listData, urlResponse) = try prepareResponse()
            self.session.nextData       = listData
            self.session.nextResponse   = urlResponse

            // when
            let ad = getAppleDownloader()
            let _ = try await ad.list(force: true)

            // then
            XCTAssert(false) // an exception must be thrown

        } catch DownloadError.parsingError {

            // expected result
            
        } catch {
            XCTAssert(false, "Unexpected exception thrown")
        }

    }
    
    func testListForceAuthenticationError() async throws {
        
        do {
            
            // given
            let (listData, urlResponse) = try prepareResponse(withDataFile: "Download Error.json")
            self.session.nextData       = listData
            self.session.nextResponse   = urlResponse

            
            // when
            let ad = getAppleDownloader()
            let _ = try await ad.list(force: true)

            // then
            XCTAssert(false) //an exception must be thrown

        } catch DownloadError.authenticationRequired {

            XCTAssert(true)

        } catch {
            XCTAssert(false, "Unexpected exception thrown")
        }

    }

    func testListForceUnknownError() async throws {
        
        do {
            
            // given
            let (listData, urlResponse) = try prepareResponse(withDataFile: "Download Unknown Error.json")
            self.session.nextData       = listData
            self.session.nextResponse   = urlResponse

            // when
            let ad = getAppleDownloader()
            let _ = try await ad.list(force: true)

            // then
            XCTAssert(false) //an exception must be thrown

        } catch DownloadError.unknownError(let errorCode) {

            XCTAssert(errorCode == 9999)

        } catch {
            XCTAssert(false, "Unexpected exception thrown : \(error)")
        }

    }
    
    func testListForceNon200Code() async throws {
        
        do {
            
            // given
            let (listData, urlResponse) = try prepareResponse(withDataFile: "Download Unknown Error.json", statusCode: 302)
            self.session.nextData       = listData
            self.session.nextResponse   = urlResponse

            // when
            let ad = getAppleDownloader()
            let _ = try await ad.list(force: true)

            // then
            XCTAssert(false) //an exception must be thrown

        } catch DownloadError.invalidResponse {

            // this is the expected answer
            XCTAssert(true)

        } catch {
            XCTAssert(false, "Unexpected exception thrown : \(error)")
        }

    }

    func testListForceNoCookies() async throws {
        
        do {
            
            // given
            let (listData, urlResponse) = try prepareResponse(withDataFile: "Download List.json", statusCode: 200, noCookies: true)
            self.session.nextData       = listData
            self.session.nextResponse   = urlResponse

            // when
            let ad = getAppleDownloader()
            let _ = try await ad.list(force: true)

            // then
            XCTAssert(false) //an exception must be thrown

        } catch DownloadError.invalidResponse {

            // this is the expected answer
            XCTAssert(true)

        } catch {
            XCTAssert(false, "Unexpected exception thrown : \(error)")
        }
    }
    
    func prepareResponse(withDataFile dataFilePath: String? = nil, statusCode : Int = 200, noCookies: Bool = false) throws -> (Data, HTTPURLResponse?) {
        
        // load list form file
        let listData : Data
        if let dfp = dataFilePath {
            let filePath = testDataDirectory().appendingPathComponent(dfp);
            listData = try Data(contentsOf: filePath)
        } else {
            listData = Data()
        }

        let url = "https://dummy"
        let urlresponse : HTTPURLResponse?
        
        if noCookies {
            urlresponse = HTTPURLResponse(url: URL(string: url)!, statusCode: statusCode, httpVersion: nil, headerFields: nil)
        } else {
            let responseHeaders = ["Set-Cookie" : "ADCDownloadAuth=qMabi%2FgxImUP3SCSL9aBmrV%2BjbIJ5b4PMxxzP%2BLYWfrncVmiaAgC%2FSsrUzBiwzh2kYLsTEM%2BjbBb%0D%0AT7%2BaqOg6Kx%2F%2BYctBYlLsmAqzyjafndmrdp2pFoHAJSNJWnjNWn29aGHAVyEjaM2uI8tJP7VzVfmF%0D%0AfB03aF3jSNyAD050Y2QBJ11ZdP%2BXR7SCy%2BfGv8xXBLiw09UTWWGiDCkoQJpHK58IZc8%3D%0D%0A;Version=1;Comment=;Domain=apple.com;Path=/;Max-Age=108000;Secure;HttpOnly;Expires=Fri, 05 Aug 2022 11:58:50 GMT"]
            urlresponse = HTTPURLResponse(url: URL(string: url)!, statusCode: statusCode, httpVersion: nil, headerFields: responseHeaders)
        }
        return (listData, urlresponse)
    }
}
