//
//  ListTest.swift
//  xcodeinstallTests
//
//  Created by Stormacq, Sebastien on 22/08/2022.
//  Updated for swift-testing migration
//

import Testing

@testable import xcodeinstall

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

@Suite("List Tests")
struct ListTest {
    var testSuite = HTTPClientTestSuite()
    
    @Test("List without force")
    func testListNoForce() async throws {
        // given
        try await testSuite.setUp()
        let ad = testSuite.getAppleDownloader()
        
        // when
        let result: DownloadList? = try await ad.list(force: false)
        
        // then
        #expect(result != nil)
        #expect(result!.downloads != nil)
        #expect(result!.downloads!.count > 0)
    }
    
    @Test("List with force")
    func testListForce() async throws {
        // given
        try await testSuite.setUp()
        let (listData, urlResponse) = try prepareResponse(withDataFile: .downloadList)
        testSuite.sessionData.nextData = listData
        testSuite.sessionData.nextResponse = urlResponse
        
        // when
        let ad = testSuite.getAppleDownloader()
        let result = try await ad.list(force: true)
        
        // then
        #expect(result.downloads != nil)
        #expect(result.downloads!.count == 1127)
    }
    
    @Test("List with force parsing error")
    func testListForceParsingError() async throws {
        // given
        try await testSuite.setUp()
        let (listData, urlResponse) = try prepareResponse()
        testSuite.sessionData.nextData = listData
        testSuite.sessionData.nextResponse = urlResponse
        
        // when
        let ad = testSuite.getAppleDownloader()
        
        // then
        #expect(throws: DownloadError.parsingError) {
            try await ad.list(force: true)
        }
    }
    
    @Test("List with force authentication error")
    func testListForceAuthenticationError() async throws {
        // given
        try await testSuite.setUp()
        let (listData, urlResponse) = try prepareResponse(withDataFile: .downloadError)
        testSuite.sessionData.nextData = listData
        testSuite.sessionData.nextResponse = urlResponse
        
        // when
        let ad = testSuite.getAppleDownloader()
        
        // then
        #expect(throws: DownloadError.authenticationRequired) {
            try await ad.list(force: true)
        }
    }
    
    @Test("List with force unknown error")
    func testListForceUnknownError() async throws {
        // given
        try await testSuite.setUp()
        let (listData, urlResponse) = try prepareResponse(withDataFile: .downloadUnknownError)
        testSuite.sessionData.nextData = listData
        testSuite.sessionData.nextResponse = urlResponse
        
        // when
        let ad = testSuite.getAppleDownloader()
        
        // then
        do {
            try await ad.list(force: true)
            #expect(false, "Expected an error to be thrown")
        } catch let error as DownloadError {
            if case .unknownError(let errorCode, _) = error {
                #expect(errorCode == 9999)
            } else {
                #expect(false, "Expected unknownError but got \(error)")
            }
        }
    }
    
    @Test("List with force non-200 code")
    func testListForceNon200Code() async throws {
        // given
        try await testSuite.setUp()
        let (listData, urlResponse) = try prepareResponse(withDataFile: .downloadUnknownError, statusCode: 302)
        testSuite.sessionData.nextData = listData
        testSuite.sessionData.nextResponse = urlResponse
        
        // when
        let ad = testSuite.getAppleDownloader()
        
        // then
        #expect(throws: DownloadError.invalidResponse) {
            try await ad.list(force: true)
        }
    }
    
    @Test("List with force no cookies")
    func testListForceNoCookies() async throws {
        // given
        try await testSuite.setUp()
        let (listData, urlResponse) = try prepareResponse(
            withDataFile: .downloadList,
            statusCode: 200,
            noCookies: true
        )
        testSuite.sessionData.nextData = listData
        testSuite.sessionData.nextResponse = urlResponse
        
        // when
        let ad = testSuite.getAppleDownloader()
        
        // then
        #expect(throws: DownloadError.invalidResponse) {
            try await ad.list(force: true)
        }
    }
    
    @Test("Account needs upgrade")
    func testAccountNeedsUpgrade() async throws {
        // given
        try await testSuite.setUp()
        let response =
            """
            {"responseId":"4a09c41c-f010-4ef0-ae03-66787439f918","resultCode":2170,"resultString":"Your developer account needs to be updated.  Please visit Apple Developer Registration.","userString":"Your developer account needs to be updated.  Please visit Apple Developer Registration.","creationTimestamp":"2022-11-29T23:50:58Z","protocolVersion":"QH65B2","userLocale":"en_US","requestUrl":"https://developer.apple.com/services-account/QH65B2/downloadws/listDownloads.action","httpCode":200}
            """
        
        let (_, urlResponse) = try prepareResponse(withDataFile: nil, statusCode: 200, noCookies: true)
        testSuite.sessionData.nextData = response.data(using: .utf8)
        testSuite.sessionData.nextResponse = urlResponse
        
        // when
        let ad = testSuite.getAppleDownloader()
        
        // then
        do {
            try await ad.list(force: true)
            #expect(false, "Expected an error to be thrown")
        } catch let error as DownloadError {
            if case .accountneedUpgrade(let code, _) = error {
                #expect(code == 2170)
            } else {
                #expect(false, "Expected accountneedUpgrade but got \(error)")
            }
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