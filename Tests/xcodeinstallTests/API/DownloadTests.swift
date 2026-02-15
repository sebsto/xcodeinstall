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

// MARK: - Download Tests
@Suite("DownloadTests")
final class DownloadTests {

    // MARK: - Test Environment
    let log = Logger(label: "DownloadTests")
    var env: MockedEnvironment

    init() async throws {
        // Setup environment for each test
        self.env = MockedEnvironment()
        self.env.secrets = MockedSecretsHandler(env: &self.env)
        try await env.secrets!.clearSecrets()
    }

    // MARK: - Helper Methods
    func getDownloadManager() -> DownloadManager {
        DownloadManager(logger: log)
    }

    func setSessionData(data: Data?, response: HTTPURLResponse?) {
        #expect(self.env.urlSessionData as? MockedURLSession != nil)
        (self.env.urlSessionData as? MockedURLSession)?.nextData = data
        (self.env.urlSessionData as? MockedURLSession)?.nextResponse = response
    }
}

// MARK: - Test Cases
extension DownloadTests {

    @Test("Test Download Manager Creation")
    func testDownloadManagerCreation() {
        // Given & When
        let dm = getDownloadManager()

        // Then — struct is always valid, just verify we can build a request
        let request = dm.request(for: "https://example.com")
        #expect(request.url?.absoluteString == "https://example.com")
    }

    @Test("Test Request Building")
    func testRequestBuilding() {
        // Given
        let dm = getDownloadManager()
        let testURL = "https://example.com/test.xip"
        let headers = ["Authorization": "Bearer token"]

        // When
        let request = dm.request(for: testURL, withHeaders: headers)

        // Then
        #expect(request.url?.absoluteString == testURL)
        #expect(request.httpMethod == "GET")
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer token")
    }

    @Test("Test Download Target Configuration")
    func testDownloadTargetConfiguration() {
        // Given
        let dstPath = URL(fileURLWithPath: "/tmp/test.xip")
        let target = DownloadTarget(totalFileSize: 1000, dstFilePath: dstPath)

        // Then
        #expect(target.totalFileSize == 1000)
        #expect(target.dstFilePath == dstPath)
    }
}
