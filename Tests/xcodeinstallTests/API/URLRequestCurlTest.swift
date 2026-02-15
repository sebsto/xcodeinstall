//
//  URLRequestCurlTest.swift
//  xcodeinstallTests
//
//  Created by Stormacq, Sebastien on 04/08/2022.
//

import Foundation
import Logging
import Testing

@testable import xcodeinstall

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

struct URLRequestCurlTest {

    let log = Logger(label: "URLRequestCurlTest")
    var agent: HTTPClient!

    init() throws {
        var env = MockedEnvironment()
        env.secrets = MockedSecretsHandler(env: &env)
        self.agent = HTTPClient(secrets: env.secrets!, urlSession: env.urlSessionData, log: log)
    }

    @Test("Test URLRequest to cURL")
    func testRequestToCurl() throws {

        //given
        let url = "https://dummy.com"
        var headers = [
            "Header1": "value1",
            "Header2": "value2",
        ]
        let data = "test data".data(using: .utf8)
        let cookie = HTTPCookie(properties: [
            .name: "cookieName", .value: "cookieValue", .path: "/", .originURL: URL(string: url)!,
        ])
        if let cookie {
            headers.merge(HTTPCookie.requestHeaderFields(with: [cookie])) { (current, _) in current }
        }

        // when
        let request = agent.request(for: url, method: .GET, withBody: data, withHeaders: headers)
        let curl = request.cURL(pretty: false)

        // then
        #expect(curl.starts(with: "curl "))
        #expect(curl.contains("-H 'Header1: value1'"))
        #expect(curl.contains("-H 'Header2: value2'"))
        #expect(curl.contains("-H 'Cookie: cookieName=cookieValue'"))
        #expect(curl.contains("-X GET 'https://dummy.com'"))
        #expect(curl.contains("--data 'test data'"))

    }

    @Test("Test URLRequest to cURL pretty print")
    func testRequestToCurlPrettyPrint() throws {

        //given
        let url = "https://dummy.com"
        var headers = [
            "Header1": "value1",
            "Header2": "value2",
        ]
        let data = "test data".data(using: .utf8)
        let cookie = HTTPCookie(properties: [
            .name: "cookieName", .value: "cookieValue", .path: "/", .originURL: URL(string: url)!,
        ])
        if let cookie {
            headers.merge(HTTPCookie.requestHeaderFields(with: [cookie])) { (current, _) in current }
        }

        // when
        let request = agent.request(for: url, method: .GET, withBody: data, withHeaders: headers)
        let curl = request.cURL(pretty: true)

        // then
        #expect(curl.starts(with: "curl "))
        #expect(curl.contains("--header 'Header1: value1'"))
        #expect(curl.contains("--header 'Header2: value2'"))
        #expect(curl.contains("--header 'Cookie: cookieName=cookieValue'"))
        #expect(curl.contains("--request GET"))
        #expect(curl.contains("--url 'https://dummy.com'"))
        #expect(curl.contains("--data 'test data'"))

    }

}
