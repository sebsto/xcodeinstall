//
//  ListTest.swift
//  xcodeinstallTests
//
//  Created by Stormacq, Sebastien on 22/08/2022.
//

import XCTest

@testable import xcodeinstall

class ListTest: HTTPClientTestCase {

    func testListNoForce() async throws {

        // given
        let ad = getAppleDownloader()

        // when
        let result: DownloadList? = try await ad.list(force: false)

        // then
        XCTAssertNotNil(result)
        XCTAssertNotNil(result!.downloads)
        XCTAssert(result!.downloads!.count > 0)
    }

    func testListForce() async throws {

        do {

            // given
            let (listData, urlResponse) = try prepareResponse(withDataFile: .downloadList)
            self.sessionData.nextData = listData
            self.sessionData.nextResponse = urlResponse

            // when
            let ad = getAppleDownloader()
            let result = try await ad.list(force: true)

            // then
            XCTAssertNotNil(result)
            XCTAssertNotNil(result.downloads)
            XCTAssert(result.downloads!.count == 1127)

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
            self.sessionData.nextData = listData
            self.sessionData.nextResponse = urlResponse

            // when
            let ad = getAppleDownloader()
            let _ = try await ad.list(force: true)

            // then
            XCTAssert(false)  // an exception must be thrown

        } catch DownloadError.parsingError {

            // expected result

        } catch {
            XCTAssert(false, "Unexpected exception thrown")
        }

    }

    func testListForceAuthenticationError() async throws {

        do {

            // given
            let (listData, urlResponse) = try prepareResponse(withDataFile: .downloadError)
            self.sessionData.nextData = listData
            self.sessionData.nextResponse = urlResponse

            // when
            let ad = getAppleDownloader()
            let _ = try await ad.list(force: true)

            // then
            XCTAssert(false)  //an exception must be thrown

        } catch DownloadError.authenticationRequired {

            XCTAssert(true)

        } catch {
            XCTAssert(false, "Unexpected exception thrown")
        }

    }

    func testListForceUnknownError() async throws {

        do {

            // given
            let (listData, urlResponse) = try prepareResponse(withDataFile: .downloadUnknownError)
            self.sessionData.nextData = listData
            self.sessionData.nextResponse = urlResponse

            // when
            let ad = getAppleDownloader()
            let _ = try await ad.list(force: true)

            // then
            XCTAssert(false)  //an exception must be thrown

        } catch DownloadError.unknownError(let errorCode, _) {

            XCTAssert(errorCode == 9999)

        } catch {
            XCTAssert(false, "Unexpected exception thrown : \(error)")
        }

    }

    func testListForceNon200Code() async throws {

        do {

            // given
            let (listData, urlResponse) = try prepareResponse(withDataFile: .downloadUnknownError, statusCode: 302)
            self.sessionData.nextData = listData
            self.sessionData.nextResponse = urlResponse

            // when
            let ad = getAppleDownloader()
            let _ = try await ad.list(force: true)

            // then
            XCTAssert(false)  //an exception must be thrown

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
            let (listData, urlResponse) = try prepareResponse(
                withDataFile: .downloadList,
                statusCode: 200,
                noCookies: true
            )
            self.sessionData.nextData = listData
            self.sessionData.nextResponse = urlResponse

            // when
            let ad = getAppleDownloader()
            let _ = try await ad.list(force: true)

            // then
            XCTAssert(false)  //an exception must be thrown

        } catch DownloadError.invalidResponse {

            // this is the expected answer
            XCTAssert(true)

        } catch {
            XCTAssert(false, "Unexpected exception thrown : \(error)")
        }
    }

    func testAccountNeedsUpgrade() async {

        do {
            // given
            let response =
                """
                {"responseId":"4a09c41c-f010-4ef0-ae03-66787439f918","resultCode":2170,"resultString":"Your developer account needs to be updated.  Please visit Apple Developer Registration.","userString":"Your developer account needs to be updated.  Please visit Apple Developer Registration.","creationTimestamp":"2022-11-29T23:50:58Z","protocolVersion":"QH65B2","userLocale":"en_US","requestUrl":"https://developer.apple.com/services-account/QH65B2/downloadws/listDownloads.action","httpCode":200}
                """

            let (_, urlResponse) = try prepareResponse(withDataFile: nil, statusCode: 200, noCookies: true)
            self.sessionData.nextData = response.data(using: .utf8)
            self.sessionData.nextResponse = urlResponse

            // when
            let ad = getAppleDownloader()
            let _ = try await ad.list(force: true)

            // then
            XCTAssert(false)  //an exception must be thrown

        } catch DownloadError.accountneedUpgrade(let code, _) {

            // an exception should be thrown
            XCTAssert(true)
            XCTAssertEqual(code, 2170)

        } catch {

            // an exception should be thrown
            XCTAssert(false)
            print("\(error)")

        }

    }

    func prepareResponse(
        withDataFile dataFile: TestData? = nil,
        statusCode: Int = 200,
        noCookies: Bool = false
    ) throws -> (Data, HTTPURLResponse?) {

        // load list form file
        let listData: Data
        if let df = dataFile {
            listData = try loadTestData(file: df)
        } else {
            listData = Data()
        }

        let url = "https://dummy"
        let urlresponse: HTTPURLResponse?

        if noCookies {
            urlresponse = HTTPURLResponse(
                url: URL(string: url)!,
                statusCode: statusCode,
                httpVersion: nil,
                headerFields: nil
            )
        } else {
            let responseHeaders = [
                "Set-Cookie":
                    "ADCDownloadAuth=qMabi%2FgxImUP3SCSL9aBmrV%2BjbIJ5b4PMxxzP%2BLYWfrncVmiaAgC%2FSsrUzBiwzh2kYLsTEM%2BjbBb%0D%0AT7%2BaqOg6Kx%2F%2BYctBYlLsmAqzyjafndmrdp2pFoHAJSNJWnjNWn29aGHAVyEjaM2uI8tJP7VzVfmF%0D%0AfB03aF3jSNyAD050Y2QBJ11ZdP%2BXR7SCy%2BfGv8xXBLiw09UTWWGiDCkoQJpHK58IZc8%3D%0D%0A;Version=1;Comment=;Domain=apple.com;Path=/;Max-Age=108000;Secure;HttpOnly;Expires=Fri, 05 Aug 2022 11:58:50 GMT"
            ]
            urlresponse = HTTPURLResponse(
                url: URL(string: url)!,
                statusCode: statusCode,
                httpVersion: nil,
                headerFields: responseHeaders
            )
        }
        return (listData, urlresponse)
    }

}
