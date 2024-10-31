//
//  HTTPClientTest.swift
//  xcodeinstallTests
//
//  Created by Stormacq, Sebastien on 21/07/2022.
//

import XCTest

@testable import xcodeinstall

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

class HTTPClientTest: HTTPClientTestCase {

    func testRequest() async throws {

        let url = "https://test.com/path"
        let username = "username"
        let password = "password"

        let headers = [
            "header1": "value1",
            "header2": "value2",
        ]
        let body = try JSONEncoder().encode(User(accountName: username, password: password))
        let request = client.request(
            for: url,
            method: .POST,
            withBody: body,
            withHeaders: headers
        )

        // test URL
        XCTAssertEqual(request.url?.debugDescription, url)

        // test method
        XCTAssertEqual(request.httpMethod, "POST")

        // test body
        XCTAssertNotNil(request.httpBody)
        let user = try JSONDecoder().decode(User.self, from: request.httpBody!)
        XCTAssertEqual(user.accountName, username)
        XCTAssertEqual(user.password, password)

        // test headers
        XCTAssertNotNil(request.allHTTPHeaderFields)
        XCTAssert(request.allHTTPHeaderFields!.count == 2)
        XCTAssertEqual(request.allHTTPHeaderFields!["header1"], "value1")
        XCTAssertEqual(request.allHTTPHeaderFields!["header2"], "value2")

    }

    // test if password are obfuscated in logs
    func testPasswordObfuscation() async throws {

        // given
        let username = "username"
        let password = "myComplexPassw0rd!"
        let body = try JSONEncoder().encode(User(accountName: username, password: password))
        let str = String(data: body, encoding: .utf8)
        XCTAssertNotNil(str)

        // when
        let obfuscated = filterPassword(str!)

        // then
        XCTAssertNotEqual(str, obfuscated)
        XCTAssertFalse(obfuscated.contains(password))
    }

    // not a super usefull test, but it helped me to understand the dynamic of Mocks
    func testDataRequestsTheURL() async throws {

        // given
        let url = "http://dummy"

        self.sessionData.nextData = Data()
        self.sessionData.nextResponse = URLResponse()

        // when
        let request = client.request(for: url)
        _ = try await self.sessionData.data(for: request, delegate: nil)

        // then
        XCTAssertEqual(self.sessionData.lastURL?.debugDescription, url)

    }

}
