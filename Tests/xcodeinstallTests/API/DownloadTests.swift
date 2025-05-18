import Foundation
import Testing

@testable import xcodeinstall

// MARK: - Download Tests
@MainActor
struct DownloadTests {

    // MARK: - Test Environment
    var sessionData: MockedURLSession!
    var sessionDownload: MockedURLSession!
    var client: HTTPClient!
    var env: MockedEnvironment!

    init() async throws {
        // Setup environment for each test
        self.env = createTestEnvironment()
        self.sessionData = env.urlSessionData as? MockedURLSession
        self.sessionDownload = env.urlSessionDownload() as? MockedURLSession
        self.client = HTTPClient(env: env)
        try await env.secrets.clearSecrets()
    }

    // MARK: - Helper Methods
    func getAppleDownloader() -> AppleDownloader {
        AppleDownloader(env: env)
    }
}

// MARK: - Test Cases
@MainActor
extension DownloadTests {

    @Test("Test Download Delegate Exists")
    func testHasDownloadDelegate() {
        // Given
        let sessionDownload = env.urlSessionDownload()

        // When
        let delegate = sessionDownload.downloadDelegate()

        // Then
        #expect(delegate != nil)
    }

    @Test("Test Download Process")
    func testDownload() async throws {
        // Given
        self.sessionDownload.nextURLSessionDownloadTask = MockedURLSessionDownloadTask()

        // When
        let file: DownloadList.File = DownloadList.File(
            filename: "file.test",
            displayName: "File Test",
            remotePath: "/file.test",
            fileSize: 100,
            sortOrder: 1,
            dateCreated: "31/01/2022",
            dateModified: "30/03/2022",
            fileFormat: DownloadList.FileFormat(fileExtension: "xip", description: "xip encryption"),
            existInCache: false
        )
        let ad = getAppleDownloader()
        let result = try await ad.download(file: file)

        // Then
        #expect(result != nil)

        // Verify if resume was called
        if let task = result as? MockedURLSessionDownloadTask {
            #expect(task.wasResumeCalled)
        } else {
            Issue.record("Error in test implementation, the return value must be a MockURLSessionDownloadTask")
        }

        // Verify if semaphore wait() was called
        if let sema = env.urlSessionDownload().downloadDelegate()?.sema as? MockedDispatchSemaphore {
            #expect(sema.wasWaitCalled())
        } else {
            Issue.record(
                "Error in test implementation, the download delegate sema must be a MockDispatchSemaphore"
            )
        }
    }

    @Test("Test Download with Invalid File Path")
    func testDownloadInvalidFile1() async throws {
        // Given
        self.sessionDownload.nextURLSessionDownloadTask = MockedURLSessionDownloadTask()

        // When
        let file: DownloadList.File = DownloadList.File(
            filename: "file.test",
            displayName: "File Test",
            remotePath: "",  // Empty path
            fileSize: 100,
            sortOrder: 1,
            dateCreated: "31/01/2022",
            dateModified: "30/03/2022",
            fileFormat: DownloadList.FileFormat(fileExtension: "xip", description: "xip encryption"),
            existInCache: false
        )
        let ad = getAppleDownloader()

        // Then
        do {
            _ = try await ad.download(file: file)
            Issue.record("Should have thrown an error")
        } catch DownloadError.invalidFileSpec {
            // Expected error
        }
    }

    @Test("Test Download with Invalid File Name")
    func testDownloadInvalidFile2() async throws {
        // Given
        self.sessionDownload.nextURLSessionDownloadTask = MockedURLSessionDownloadTask()

        // When
        let file: DownloadList.File = DownloadList.File(
            filename: "",  // Empty filename
            displayName: "File Test",
            remotePath: "/file.test",
            fileSize: 100,
            sortOrder: 1,
            dateCreated: "31/01/2022",
            dateModified: "30/03/2022",
            fileFormat: DownloadList.FileFormat(fileExtension: "xip", description: "xip encryption"),
            existInCache: false
        )
        let ad = getAppleDownloader()

        // Then
        do {
            _ = try await ad.download(file: file)
            Issue.record("Should have thrown an error")
        } catch DownloadError.invalidFileSpec {
            // Expected error
        }
    }
}
