//
//  AuthenticationTest.swift
//  xcodeinstallTests
//
//  Created by Stormacq, Sebastien on 21/07/2022.
//

import XCTest

@testable import xcodeinstall

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

class AuthenticationSRPTest: HTTPClientTestCase {

    // test authentication returns 401
    func testAuthenticationInvalidUsernamePassword401() async {

        let url = "https://dummy"

        self.sessionData.nextData = getSRPInitResponse()

        self.sessionData.nextResponse = HTTPURLResponse(
            url: URL(string: url)!,
            statusCode: 401,
            httpVersion: nil,
            headerFields: getHashcashHeaders()
        )

        do {
            let authenticator = getAppleAuthenticator()
            authenticator.session = getAppleSession()

            _ = try await authenticator.startAuthentication(
                with: .srp,
                username: "username",
                password: "password"
            )
            XCTAssert(false, "No exception thrown")

        } catch AuthenticationError.invalidUsernamePassword {

        } catch {
            XCTAssert(false, "Invalid exception thrown \(error)")
        }
    }

    // test authentication returns 200
    func testAuthentication200() async {
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

        do {
            let authenticator = getAppleAuthenticator()
            authenticator.session = getAppleSession()

            try await authenticator.startAuthentication(
                with: .srp,
                username: "username",
                password: "password"
            )

            XCTAssertNotNil(authenticator.session)
            //XCTAssertNotNil(authenticator.cookies)

            // test apple session
            XCTAssertEqual(authenticator.session.scnt, "scnt")
            XCTAssertEqual(authenticator.session.xAppleIdSessionId, "x-apple-id")
            XCTAssertEqual(authenticator.session.itcServiceKey?.authServiceKey, "key")
            XCTAssertEqual(authenticator.session.itcServiceKey?.authServiceUrl, "url")

            // test cookie
            //XCTAssertEqual(cookies, getCookieString())

        } catch {
            XCTAssert(false, "Exception thrown : \(error)")
        }
    }

    // test authentication with No Apple Service Key
    func testAuthenticationWithNoAppleServiceKey() async {
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

        do {
            let authenticator = getAppleAuthenticator()
            authenticator.session = getAppleSession()
            authenticator.session.itcServiceKey = nil

            try await authenticator.startAuthentication(
                with: .srp,
                username: "username",
                password: "password"
            )

            XCTAssert(false, "An exception must be thrown)")

        } catch AuthenticationError.unableToRetrieveAppleServiceKey {
            // success
        } catch {
            XCTAssert(false, "Unknown Exception thrown")
        }
    }

    // test authentication throws an error
    func testAuthenticationWithError() async {
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
            XCTAssert(false, "No exception thrown")

        } catch let error as URLError {

            // verify it returns an error code
            XCTAssertNotNil(error)
            XCTAssert(error.code == URLError.badServerResponse)

        } catch AuthenticationError.unexpectedHTTPReturnCode(let code) {

            // this is the normal case for this test
            XCTAssertEqual(code, 500)

        } catch {
            XCTAssert(false, "Invalid exception thrown : \(error)")
        }
    }

    // test authentication returns 401
    func testAuthenticationInvalidUsernamePassword403() async {

        let url = "https://dummy"

        self.sessionData.nextData = getSRPInitResponse()
        self.sessionData.nextResponse = HTTPURLResponse(
            url: URL(string: url)!,
            statusCode: 403,
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
            XCTAssert(false, "No exception thrown")

        } catch AuthenticationError.invalidUsernamePassword {

        } catch {
            XCTAssert(false, "Invalid exception thrown \(error)")
        }

    }

    // test authentication returns unhandled http sttaus code
    func testAuthenticationUnknownStatusCode() async {

        let url = "https://dummy"

        self.sessionData.nextData = getSRPInitResponse()
        self.sessionData.nextResponse = HTTPURLResponse(
            url: URL(string: url)!,
            statusCode: 100,
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
            XCTAssert(false, "No exception thrown")

        } catch AuthenticationError.unexpectedHTTPReturnCode(let code) {
            XCTAssertEqual(code, 100)
        } catch {
            XCTAssert(false, "Invalid exception thrown \(error)")
        }

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

    private func getHashcashHeaders() -> [String: String] {
        [
            "X-Apple-HC-Bits": "11",
            "X-Apple-HC-Challenge": "4d74fb15eb23f465f1f6fcbf534e5877",
        ]
    }
    private func getCookieString() -> String {
        "dslang=GB-EN; Domain=apple.com; Path=/; Secure; HttpOnly, site=GBR; Domain=apple.com; Path=/; Secure; HttpOnly, acn01=tP...QTb; Max-Age=31536000; Expires=Fri, 21-Jul-2023 13:14:09 GMT; Domain=apple.com; Path=/; Secure; HttpOnly, myacinfo=DAWTKN....a47V3; Domain=apple.com; Path=/; Secure; HttpOnly, aasp=DAA5DA...4EAE46; Domain=idmsa.apple.com; Path=/; Secure; HttpOnly"
    }

}
