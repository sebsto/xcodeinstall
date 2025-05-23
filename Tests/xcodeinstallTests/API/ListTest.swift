//
//  ListTest.swift
//  xcodeinstallTests
//
//  Created by Stormacq, Sebastien on 22/08/2022.
//

import Testing

@testable import xcodeinstall

import Foundation

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

#if canImport(FoundationEssentials)
import FoundationEssentials
#endif

extension DownloadTests {

    @Test("Test list no force")
    func testListNoForce() async throws {

        // given
        let ad = getAppleDownloader()

        // when
        let result: DownloadList? = try await ad.list(force: false)

        // then
        #expect(result != nil)
        #expect(result?.downloads != nil)
        #expect(result!.downloads!.count > 0)
    }

    @Test("Test list force")
    func testListForce() async throws {
        let _ = await #expect(throws: Never.self) {
            // given
            let (listData, urlResponse) = try self.prepareResponse(withDataFile: .downloadList)
            self.setSessionData(data: listData, response: urlResponse)

            // when
            let ad = self.getAppleDownloader()
            let result = try await ad.list(force: true)

            // then
            #expect(result.downloads != nil)
            #expect(result.downloads!.count == 1127)
        }
    }

    @Test("Test list force with parsing error"
        //   ,.enabled(if: false)
    )
    func testListForceParsingError() async throws {

        let error = await #expect(throws: DownloadError.self) {

            // given
            let (listData, urlResponse) = try self.prepareResponse()
            self.setSessionData(data: listData, response: urlResponse)

            // when
            let ad = self.getAppleDownloader()
            let _ = try await ad.list(force: true)

            // then
            // an exception must be thrown

        } 
        #expect(error == DownloadError.parsingError(error: nil))
    }

    @Test("Test list force with authentication error")
    func testListForceAuthenticationError() async throws {

        let error = await #expect(throws: DownloadError.self) {

            // given
            let (listData, urlResponse) = try self.prepareResponse(withDataFile: .downloadError)
            self.setSessionData(data: listData, response: urlResponse)

            // when
            let ad = self.getAppleDownloader()
            let _ = try await ad.list(force: true)

            // then
            //an exception must be thrown

        }
        #expect(error == DownloadError.authenticationRequired)
    }

    @Test("Test list force with unknown error")
    func testListForceUnknownError() async throws {

        let error = await #expect(throws: DownloadError.self){

            // given
            let (listData, urlResponse) = try self.prepareResponse(withDataFile: .downloadUnknownError)
            self.setSessionData(data: listData, response: urlResponse)

            // when
            let ad = self.getAppleDownloader()
            let _ = try await ad.list(force: true)

            // then
            //an exception must be thrown

        } 
        #expect(error == DownloadError.unknownError(errorCode: 9999, errorMessage: "Unknown error"))
    }

    @Test("Test list force with non 200 code")
    func testListForceNon200Code() async throws {

        let error = await #expect(throws: DownloadError.self) {

            // given
            let (listData, urlResponse) = try self.prepareResponse(withDataFile: .downloadUnknownError, statusCode: 302)
            self.setSessionData(data: listData, response: urlResponse)

            // when
            let ad = self.getAppleDownloader()
            let _ = try await ad.list(force: true)

            // then
            //an exception must be thrown

        } 
        
        #expect(error == DownloadError.invalidResponse)
    }

    @Test("Test list force with no cookies")
    func testListForceNoCookies() async throws {

        let error = await #expect(throws: DownloadError.self) {

            // given
            let (listData, urlResponse) = try self.prepareResponse(
                withDataFile: .downloadList,
                statusCode: 200,
                noCookies: true
            )
            self.setSessionData(data: listData, response: urlResponse)

            // when
            let ad = self.getAppleDownloader()
            let _ = try await ad.list(force: true)

            // then
            //an exception must be thrown

        } 
        
        #expect(error == DownloadError.invalidResponse)
    }

    @Test("Test list force with account needs upgrade")
    func testAccountNeedsUpgrade() async {

        let error = await #expect(throws: DownloadError.self) {
            // given
            let response =
                """
                {"responseId":"4a09c41c-f010-4ef0-ae03-66787439f918","resultCode":2170,"resultString":"Your developer account needs to be updated.  Please visit Apple Developer Registration.","userString":"Your developer account needs to be updated.  Please visit Apple Developer Registration.","creationTimestamp":"2022-11-29T23:50:58Z","protocolVersion":"QH65B2","userLocale":"en_US","requestUrl":"https://developer.apple.com/services-account/QH65B2/downloadws/listDownloads.action","httpCode":200}
                """

            let (_, urlResponse) = try self.prepareResponse(withDataFile: nil, statusCode: 200, noCookies: true)
            self.setSessionData(data: response.data(using: .utf8), response: urlResponse)

            // when
            let ad = self.getAppleDownloader()
            let _ = try await ad.list(force: true)

            // then
            //an exception must be thrown

        } 
        
        #expect(error == DownloadError.accountneedUpgrade(errorCode: 2170, errorMessage: "Your developer account needs to be updated.  Please visit Apple Developer Registration."))
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
