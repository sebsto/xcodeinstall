//
//  URLRequestCurlTest.swift
//  xcodeinstallTests
//
//  Created by Stormacq, Sebastien on 04/08/2022.
//

import XCTest

@testable import xcodeinstall

class URLRequestCurlTest: XCTestCase {

    var agent: HTTPClient!

    override func setUpWithError() throws {

        env = Environment.mock

        try super.setUpWithError()
        self.agent = HTTPClient()
    }

    func testRequestToCurl() throws {

        //given
        let url = "https://dummy.com"
        var headers = [
            "header1": "value1",
            "header2": "value2",
        ]
        let data = "test data".data(using: .utf8)
        let cookie = HTTPCookie(properties: [.name: "cookieName", .value: "cookieValue", .path: "/", .originURL: url])
        if let cookie {
            headers.merge(HTTPCookie.requestHeaderFields(with: [cookie])) { (current, _) in current }
        }

        // when
        let request = agent.request(for: url, method: .GET, withBody: data, withHeaders: headers)
        let curl = request.cURL(pretty: false)

        // then
        XCTAssertNotNil(curl)
        XCTAssert(curl.starts(with: "curl "))
        XCTAssert(curl.contains("-H 'header1: value1'"))
        XCTAssert(curl.contains("-H 'header2: value2'"))
        XCTAssert(curl.contains("-H 'Cookie: cookieName=cookieValue'"))
        XCTAssert(curl.contains("-X GET 'https://dummy.com'"))
        XCTAssert(curl.contains("--data 'test data'"))

    }

    func testRequestToCurlPrettyPrint() throws {

        //given
        let url = "https://dummy.com"
        var headers = [
            "header1": "value1",
            "header2": "value2",
        ]
        let data = "test data".data(using: .utf8)
        let cookie = HTTPCookie(properties: [.name: "cookieName", .value: "cookieValue", .path: "/", .originURL: url])
        if let cookie {
            headers.merge(HTTPCookie.requestHeaderFields(with: [cookie])) { (current, _) in current }
        }

        // when
        let request = agent.request(for: url, method: .GET, withBody: data, withHeaders: headers)
        let curl = request.cURL(pretty: true)

        // then
        XCTAssertNotNil(curl)
        XCTAssert(curl.starts(with: "curl "))
        XCTAssert(curl.contains("--header 'header1: value1'"))
        XCTAssert(curl.contains("--header 'header2: value2'"))
        XCTAssert(curl.contains("--header 'Cookie: cookieName=cookieValue'"))
        XCTAssert(curl.contains("--request GET"))
        XCTAssert(curl.contains("--url 'https://dummy.com'"))
        XCTAssert(curl.contains("--data 'test data'"))

    }

}
