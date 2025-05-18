//
//  AuthenticationTest.swift
//  xcodeinstallTests
//
//  Created by Stormacq, Sebastien on 21/07/2022.
//

import Testing

@testable import xcodeinstall

#if canImport(FoundationNetworking)
import FoundationNetworking
#else
import Foundation
#endif

extension AuthenticationTests {

    // test authentication returns 401
    @Test("Test srp authentication returns 401")
    func testSRPAuthenticationInvalidUsernamePassword401() async {

        let url = "https://dummy"

        self.sessionData.nextData = getSRPInitResponse()

        self.sessionData.nextResponse = HTTPURLResponse(
            url: URL(string: url)!,
            statusCode: 401,
            httpVersion: nil,
            headerFields: getHashcashHeaders()
        )

        let error = await #expect(throws: AuthenticationError.self) {
            let authenticator = getAppleAuthenticator()
            authenticator.session = getAppleSession()

            _ = try await authenticator.startAuthentication(
                with: .srp,
                username: "username",
                password: "password"
            )
        }
        #expect(error == AuthenticationError.invalidUsernamePassword)
    }

    // test authentication returns 200
    @Test("Test SRP authentication returns 200")
    func testSRPAuthentication200() async {
        let url = "https://dummy"
        var header = [String: String]()
        header["Set-Cookie"] = getCookieString()
        header["X-Apple-ID-Session-Id"] = "x-apple-id"
        header["scnt"] = "scnt"

        self.sessionData.nextData = getSRPInitResponse()
        self.sessionData.nextResponse = HTTPURLResponse(
            url: URL(string: url)!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: header
        )

        let _ = await #expect(throws: Never.self) {
            let authenticator = getAppleAuthenticator()
            authenticator.session = getAppleSession()

            try await authenticator.startAuthentication(
                with: .srp,
                username: "username",
                password: "password"
            )

            // test apple session
            #expect(authenticator.session.scnt == "scnt")
            #expect(authenticator.session.xAppleIdSessionId == "x-apple-id")
            #expect(authenticator.session.itcServiceKey?.authServiceKey == "key")
            #expect(authenticator.session.itcServiceKey?.authServiceUrl == "url")

            // test cookie
            //XCTAssertEqual(cookies, getCookieString())

        }
    }

    // test authentication with No Apple Service Key
    @Test("Test srp authentication with No Apple Service Key")
    func testSRPAuthenticationWithNoAppleServiceKey() async {
        let url = "https://dummy"
        var header = [String: String]()
        header["Set-Cookie"] = getCookieString()
        header["X-Apple-ID-Session-Id"] = "x-apple-id"
        header["scnt"] = "scnt"

        self.sessionData.nextData = getSRPInitResponse()
        self.sessionData.nextResponse = HTTPURLResponse(
            url: URL(string: url)!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: header
        )

        let error = await #expect(throws: AuthenticationError.self) {
            let authenticator = getAppleAuthenticator()
            authenticator.session = getAppleSession()
            authenticator.session.itcServiceKey = nil

            try await authenticator.startAuthentication(
                with: .srp,
                username: "username",
                password: "password"
            )
        }
        #expect(error == AuthenticationError.unableToRetrieveAppleServiceKey(nil))
    }

    // test authentication throws an error
    @Test("Test srp authentication throws an error")
    func testSRPAuthenticationWithError() async {
        let url = "https://dummy"

        self.sessionData.nextData = getSRPInitResponse()
        self.sessionData.nextResponse = HTTPURLResponse(
            url: URL(string: url)!,
            statusCode: 500,
            httpVersion: nil,
            headerFields: nil
        )

        do {
            let authenticator = getAppleAuthenticator()
            authenticator.session = getAppleSession()

            _ = try await authenticator.startAuthentication(
                with: .srp,
                username: "username",
                password: "password"
            )
            Issue.record("No exception thrown")

        } catch let error as URLError {

            // verify it returns an error code
            #expect(error.code == URLError.badServerResponse)

        } catch AuthenticationError.unexpectedHTTPReturnCode(let code) {

            // this is the normal case for this test
            #expect(code == 500)

        } catch {
            Issue.record("Invalid exception thrown : \(error)")
        }
    }

    // test authentication returns 401
    @Test("Test srp authentication returns 403")
    func testSRPAuthenticationInvalidUsernamePassword403() async {

        let url = "https://dummy"

        self.sessionData.nextData = getSRPInitResponse()
        self.sessionData.nextResponse = HTTPURLResponse(
            url: URL(string: url)!,
            statusCode: 403,
            httpVersion: nil,
            headerFields: nil
        )

        let error = await #expect(throws: AuthenticationError.self) {
            let authenticator = getAppleAuthenticator()
            authenticator.session = getAppleSession()

            _ = try await authenticator.startAuthentication(
                with: .srp,
                username: "username",
                password: "password"
            )
        }
        #expect(error == AuthenticationError.invalidUsernamePassword)
    }

    // test authentication returns unhandled http sttaus code
    @Test("Test srp authentication returns unhandled http status code")
    func testSRPAuthenticationUnknownStatusCode() async {

        let url = "https://dummy"

        self.sessionData.nextData = getSRPInitResponse()
        self.sessionData.nextResponse = HTTPURLResponse(
            url: URL(string: url)!,
            statusCode: 100,
            httpVersion: nil,
            headerFields: nil
        )

        let error = await #expect(throws: AuthenticationError.self) {
            let authenticator = getAppleAuthenticator()
            authenticator.session = getAppleSession()

            _ = try await authenticator.startAuthentication(
                with: .srp,
                username: "username",
                password: "password"
            )
        }
        #expect(error == AuthenticationError.unexpectedHTTPReturnCode(code: 100))
    }

    private func getSRPInitResponse() -> Data {
        """
             {
             "iteration" : 1160,
             "salt" : "iVGSz0+eXAe5jzBsuSH9Gg==",
             "protocol" : "s2k_fo",
             "b" : "feF9PcfeU6pKeZb27kxM080eOPvg0wZurW6sGglwhIi63VPyQE1FfU1NKdU5bRHpGYcz23AKetaZWX6EqlIUYsmguN7peY9OU74+V16kvPaMFtSvS4LUrl8W+unt2BTlwRoINTYVgoIiLwXFKAowH6dA9HGaOy8TffKw/FskGK1rPqf8TZJ3IKWk6LA8AAvNhQhaH2/rdtdysJpV+T7eLpoMlcILWCOVL1mzAeTr3lMO4UdcnPokjWIoHIEJXDF8XekRbqSeCZvMlZBP1qSeRFwPuxz//doEk0AS2wU2sZFinPmfz4OV2ESQ4j9lfxE+NvapT+fPAmEUysUL61piMw==",
             "c" : "d-74e-7f288e09-93e6-11ef-9a9c-278293010698:PRN"
             }
        """.data(using: .utf8)!
    }
}
