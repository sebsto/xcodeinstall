import Foundation
import Logging
import Testing

@testable import xcodeinstall

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

// MARK: - Authentication Tests
@MainActor
struct AuthenticationTests {

    let log = Logger(label: "AuthenticationTests")

    // MARK: - Test Environment
    var sessionData: MockedURLSession!
    var client: HTTPClient!
    var env: MockedEnvironment

    init() async throws {
        // Setup environment for each test
        self.env = MockedEnvironment()
        self.env.secrets = MockedSecretsHandler(env: &self.env)
        self.sessionData = env.urlSessionData as? MockedURLSession
        self.client = HTTPClient(log: log)
        self.client.environment = env
        try await env.secrets!.clearSecrets()
    }

    // MARK: - Helper Methods
    func getAppleSession() -> AppleSession {
        AppleSession(
            itcServiceKey: AppleServiceKey(authServiceUrl: "url", authServiceKey: "key"),
            xAppleIdSessionId: "x_apple_id_session_id",
            scnt: "scnt",
            hashcash: "hashcash"
        )
    }

    func getAppleAuthenticator() -> AppleAuthenticator {
        let aa = AppleAuthenticator(log: log)
        aa.environment = self.env
        return aa
    }

    func getHashcashHeaders() -> [String: String] {
        [
            "X-Apple-HC-Bits": "11",
            "X-Apple-HC-Challenge": "4d74fb15eb23f465f1f6fcbf534e5877",
        ]
    }

    func getCookieString() -> String {
        "dslang=GB-EN; Domain=apple.com; Path=/; Secure; HttpOnly, site=GBR; Domain=apple.com; Path=/; Secure; HttpOnly, acn01=tP...QTb; Max-Age=31536000; Expires=Fri, 21-Jul-2023 13:14:09 GMT; Domain=apple.com; Path=/; Secure; HttpOnly, myacinfo=DAWTKN....a47V3; Domain=apple.com; Path=/; Secure; HttpOnly, aasp=DAA5DA...4EAE46; Domain=idmsa.apple.com; Path=/; Secure; HttpOnly"
    }
}

// MARK: - Test Cases
@MainActor
extension AuthenticationTests {

    @Test("Test Apple Service Key Retrieval")
    func testAppleServiceKey() async throws {
        let url = "https://dummy"
        self.sessionData.nextData = try JSONEncoder().encode(
            AppleServiceKey(authServiceUrl: "url", authServiceKey: "key")
        )
        self.sessionData.nextResponse = HTTPURLResponse(
            url: URL(string: url)!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )

        let authenticator = getAppleAuthenticator()
        let serviceKey = try await authenticator.getAppleServicekey()

        #expect(serviceKey.authServiceKey == "key")
    }

    @Test("Test Apple Service Key Error Handling")
    func testAppleServiceKeyWithError() async throws {
        let url = "https://dummy"
        self.sessionData.nextData = try JSONEncoder().encode(
            AppleServiceKey(authServiceUrl: "url", authServiceKey: "key")
        )
        self.sessionData.nextResponse = HTTPURLResponse(
            url: URL(string: url)!,
            statusCode: 500,
            httpVersion: nil,
            headerFields: nil
        )

        let authenticator = getAppleAuthenticator()

        do {
            _ = try await authenticator.getAppleServicekey()
            Issue.record("Should have thrown an error")
        } catch is URLError {
            // Expected error
        }
    }

    @Test("Test Apple Hashcash Generation")
    func testAppleHashcash() async throws {
        let url = "https://dummy"
        self.sessionData.nextData = Data()
        self.sessionData.nextResponse = HTTPURLResponse(
            url: URL(string: url)!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: getHashcashHeaders()
        )

        let authenticator = getAppleAuthenticator()
        let hashcash = try await authenticator.getAppleHashcash(itServiceKey: "dummy", date: "20230223170600")

        #expect(hashcash == "1:11:20230223170600:4d74fb15eb23f465f1f6fcbf534e5877::6373")
    }

    @Test("Test Apple Hashcash Error Handling")
    func testAppleHashcashWithError() async throws {
        let url = "https://dummy"
        self.sessionData.nextData = Data()
        self.sessionData.nextResponse = HTTPURLResponse(
            url: URL(string: url)!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )

        let authenticator = getAppleAuthenticator()

        do {
            _ = try await authenticator.getAppleHashcash(itServiceKey: "dummy")
            Issue.record("Should have thrown an error")
        } catch AuthenticationError.missingHTTPHeaders {
            // Expected error
        }
    }
}

// MARK: - Authentication Flow Tests
@MainActor
extension AuthenticationTests {

    @Test("Test Authentication with Invalid Credentials (401)")
    func testAuthenticationInvalidUsernamePassword401() async throws {
        let url = "https://dummy"

        self.sessionData.nextData = Data()
        self.sessionData.nextResponse = HTTPURLResponse(
            url: URL(string: url)!,
            statusCode: 401,
            httpVersion: nil,
            headerFields: getHashcashHeaders()
        )

        let authenticator = getAppleAuthenticator()
        authenticator.session = getAppleSession()

        let _ = await #expect(throws: AuthenticationError.self) {
            _ = try await authenticator.startAuthentication(
                with: .usernamePassword,
                username: "username",
                password: "password"
            )
        }
    }

    @Test("Test Successful Authentication (200)")
    func testAuthentication200() async throws {
        let url = "https://dummy"
        var header = [String: String]()
        header["Set-Cookie"] = getCookieString()
        header["X-Apple-ID-Session-Id"] = "x-apple-id"
        header["scnt"] = "scnt"

        self.sessionData.nextData = Data()
        self.sessionData.nextResponse = HTTPURLResponse(
            url: URL(string: url)!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: header
        )

        let authenticator = getAppleAuthenticator()
        authenticator.session = getAppleSession()

        try await authenticator.startAuthentication(
            with: .usernamePassword,
            username: "username",
            password: "password"
        )

        // Test apple session
        #expect(authenticator.session.scnt == "scnt")
        #expect(authenticator.session.xAppleIdSessionId == "x-apple-id")
        #expect(authenticator.session.itcServiceKey?.authServiceKey == "key")
        #expect(authenticator.session.itcServiceKey?.authServiceUrl == "url")
    }

    @Test("Test Authentication with No Apple Service Key")
    func testAuthenticationWithNoAppleServiceKey() async throws {
        let url = "https://dummy"
        var header = [String: String]()
        header["Set-Cookie"] = getCookieString()
        header["X-Apple-ID-Session-Id"] = "x-apple-id"
        header["scnt"] = "scnt"

        self.sessionData.nextData = Data()
        self.sessionData.nextResponse = HTTPURLResponse(
            url: URL(string: url)!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: header
        )

        let authenticator = getAppleAuthenticator()
        authenticator.session = getAppleSession()
        authenticator.session.itcServiceKey = nil

        let error = await #expect(throws: AuthenticationError.self) {
            try await authenticator.startAuthentication(
                with: .usernamePassword,
                username: "username",
                password: "password"
            )
        }
        #expect(error == AuthenticationError.unableToRetrieveAppleServiceKey(nil))
    }

    @Test("Test Authentication with Server Error")
    func testAuthenticationWithError() async throws {
        let url = "https://dummy"

        self.sessionData.nextData = Data()
        self.sessionData.nextResponse = HTTPURLResponse(
            url: URL(string: url)!,
            statusCode: 500,
            httpVersion: nil,
            headerFields: nil
        )

        let authenticator = getAppleAuthenticator()
        authenticator.session = getAppleSession()

        let error = await #expect(throws: AuthenticationError.self) {
            _ = try await authenticator.startAuthentication(
                with: .usernamePassword,
                username: "username",
                password: "password"
            )
            Issue.record("Should have thrown an error")
        }
        #expect(error == AuthenticationError.unexpectedHTTPReturnCode(code: 500))
    }

    @Test("Test Authentication with Invalid Credentials (403)")
    func testAuthenticationInvalidUsernamePassword403() async throws {
        let url = "https://dummy"

        self.sessionData.nextData = Data()
        self.sessionData.nextResponse = HTTPURLResponse(
            url: URL(string: url)!,
            statusCode: 403,
            httpVersion: nil,
            headerFields: nil
        )

        let authenticator = getAppleAuthenticator()
        authenticator.session = getAppleSession()

        let error = await #expect(throws: AuthenticationError.self) {
            _ = try await authenticator.startAuthentication(
                with: .usernamePassword,
                username: "username",
                password: "password"
            )
        }
        #expect(error == AuthenticationError.invalidUsernamePassword)
    }

    @Test("Test Authentication with Unknown Status Code")
    func testAuthenticationUnknownStatusCode() async throws {
        let url = "https://dummy"

        self.sessionData.nextData = Data()
        self.sessionData.nextResponse = HTTPURLResponse(
            url: URL(string: url)!,
            statusCode: 100,
            httpVersion: nil,
            headerFields: nil
        )

        let authenticator = getAppleAuthenticator()
        authenticator.session = getAppleSession()

        let error = await #expect(throws: AuthenticationError.self) {
            _ = try await authenticator.startAuthentication(
                with: .usernamePassword,
                username: "username",
                password: "password"
            )
            Issue.record("Should have thrown an error")
        }
        #expect(error == AuthenticationError.unexpectedHTTPReturnCode(code: 100))
    }

    @Test("Test Signout")
    func testSignout() async throws {
        let url = "https://dummy"
        self.sessionData.nextData = Data()
        self.sessionData.nextResponse = HTTPURLResponse(
            url: URL(string: url)!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )

        let authenticator = getAppleAuthenticator()
        authenticator.session = getAppleSession()

        try await authenticator.signout()
        // No assertion needed - just verifying it doesn't throw
    }
}
