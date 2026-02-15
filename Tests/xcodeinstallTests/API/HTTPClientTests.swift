import Foundation
import Logging
import Testing

@testable import xcodeinstall

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

#if canImport(FoundationEssentials)
import FoundationEssentials
#endif

// MARK: - Test Suite Setup
struct HTTPClientTests {

    // MARK: - Test Environment
    var sessionData: MockedURLSession!
    var sessionDownload: MockedURLSession!
    var client: HTTPClient!
    var env: MockedEnvironment
    var log = Logger(label: "HTTPClientTests")

    init() async throws {
        // Setup environment for each test
        self.env = MockedEnvironment()
        self.env.secrets = MockedSecretsHandler(env: &self.env)
        self.sessionData = env.urlSessionData as? MockedURLSession
        self.sessionDownload = env.urlSessionDownload as? MockedURLSession
        self.client = HTTPClient(secrets: env.secrets!, urlSession: env.urlSessionData, log: log)
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
}

// MARK: - Test Cases
extension HTTPClientTests {

    @Test("Test HTTP Request Creation")
    func testRequest() async throws {
        let url = "https://test.com/path"
        let username = "username"
        let password = "password"

        let headers = [
            "Header1": "value1",
            "Header2": "value2",
        ]
        let body = try JSONEncoder().encode(User(accountName: username, password: password))
        let request = client.request(
            for: url,
            method: .POST,
            withBody: body,
            withHeaders: headers
        )

        // Test URL
        #expect(request.url?.debugDescription == url)

        // Test method
        #expect(request.httpMethod == "POST")

        // Test body
        #expect(request.httpBody != nil)
        let user = try JSONDecoder().decode(User.self, from: request.httpBody!)
        #expect(user.accountName == username)
        #expect(user.password == password)

        // Test headers
        #expect(request.allHTTPHeaderFields != nil)
        #expect(request.allHTTPHeaderFields?.count == 2)
        #expect(request.allHTTPHeaderFields?["Header1"] == "value1")
        #expect(request.allHTTPHeaderFields?["Header2"] == "value2")
    }

    @Test("Test Password Obfuscation in Logs")
    func testPasswordObfuscation() async throws {
        // Given
        let username = "username"
        let password = "myComplexPassw0rd!"
        let body = try JSONEncoder().encode(User(accountName: username, password: password))
        let str = String(data: body, encoding: .utf8)
        #expect(str != nil)

        // When
        let obfuscated = _filterPassword(str!)

        // Then
        #expect(str != obfuscated)
        #expect(!obfuscated.contains(password))
    }

    @Test("Test Data Request URL")
    func testDataRequestsTheURL() async throws {
        // Given
        let url = "http://dummy"

        self.sessionData.nextData = Data()
        // Create a mock URLResponse that works on both platforms
        self.sessionData.nextResponse = URLResponse(
            url: URL(string: "http://dummy")!,
            mimeType: nil,
            expectedContentLength: 0,
            textEncodingName: nil
        )

        // When
        let request = client.request(for: url)
        _ = try await self.sessionData.data(for: request, delegate: nil)

        // Then
        #expect(self.sessionData.lastURL?.debugDescription == url)
    }
}
