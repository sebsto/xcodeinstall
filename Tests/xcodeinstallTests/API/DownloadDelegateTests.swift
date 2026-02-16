import Foundation
import Logging
import Testing

@testable import xcodeinstall

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

// MARK: - DownloadDelegate Tests
@Suite("DownloadDelegate Tests", .serialized)
struct DownloadDelegateTests {

    // MARK: - Test Environment
    let log = Logger(label: "DownloadDelegateTests")
    let fileManager = FileManager.default

    /// Runs `body` with a freshly created temporary directory, removing it on exit.
    func withTempDirectory<T>(_ body: (URL) throws -> T) throws -> T {
        let tempDir = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: tempDir) }
        return try body(tempDir)
    }

    /// Async variant of `withTempDirectory`.
    func withTempDirectory<T>(_ body: (URL) async throws -> T) async throws -> T {
        let tempDir = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: tempDir) }
        return try await body(tempDir)
    }

    /// Creates a DownloadDelegate backed by an AsyncThrowingStream, returning both.
    /// The stream can be consumed to verify what the delegate yielded/threw.
    func makeDelegate(
        dstPath: URL,
        fileHandler: FileHandlerProtocol = MockedFileHandler(),
        totalBytes: Int64 = 1000,
        startTime: Date = Date.now
    ) -> (DownloadDelegate, AsyncThrowingStream<DownloadProgress, Error>) {
        var capturedContinuation: AsyncThrowingStream<DownloadProgress, Error>.Continuation!
        let stream = AsyncThrowingStream<DownloadProgress, Error> { continuation in
            capturedContinuation = continuation
        }
        let delegate = DownloadDelegate(
            continuation: capturedContinuation,
            totalBytes: totalBytes,
            startTime: startTime,
            dstPath: dstPath,
            fileHandler: fileHandler,
            log: log
        )
        return (delegate, stream)
    }
}

// MARK: - didFinishDownloadingTo Tests
extension DownloadDelegateTests {

    @Test("Successful file move via didFinishDownloadingTo")
    func testDidFinishDownloadingTo_movesFile() async throws {
        try await withTempDirectory { tempDir in
            // Given — a source file at a temp location and a destination path
            let srcFile = tempDir.appendingPathComponent("source.xip")
            let dstFile = tempDir.appendingPathComponent("destination.xip")
            // Pad content to exceed 10_000 bytes so it doesn't trigger error page detection
            let paddedContent = String(repeating: "x", count: 10_001)
            try paddedContent.data(using: .utf8)!.write(to: srcFile)

            let mockFileHandler = MockedFileHandler()
            let (delegate, stream) = makeDelegate(dstPath: dstFile, fileHandler: mockFileHandler)

            let session = URLSession(configuration: .ephemeral)
            defer { session.invalidateAndCancel() }

            // When — call didFinishDownloadingTo with the source file location
            let dummyTask = session.downloadTask(with: URL(string: "https://example.com")!)
            delegate.urlSession(session, downloadTask: dummyTask, didFinishDownloadingTo: srcFile)

            // Then — the stream should finish without error
            await #expect(throws: Never.self) {
                for try await _ in stream {}
            }

            // Verify the file handler was asked to move from src to dst
            #expect(mockFileHandler.moveSrc == srcFile)
            #expect(mockFileHandler.moveDst == dstFile)
        }
    }

    @Test("Error page detection with Error tag in small download")
    func testDidFinishDownloadingTo_detectsErrorPage() async throws {
        try await withTempDirectory { tempDir in
            // Given — a small file containing an error page marker
            let srcFile = tempDir.appendingPathComponent("error_response.xml")
            let errorContent = "<Error><Code>AccessDenied</Code></Error>"
            try errorContent.data(using: .utf8)!.write(to: srcFile)

            let dstFile = tempDir.appendingPathComponent("destination.xip")
            let (delegate, stream) = makeDelegate(dstPath: dstFile)

            let session = URLSession(configuration: .ephemeral)
            defer { session.invalidateAndCancel() }

            // When — call didFinishDownloadingTo with the error page file
            let dummyTask = session.downloadTask(with: URL(string: "https://example.com")!)
            delegate.urlSession(session, downloadTask: dummyTask, didFinishDownloadingTo: srcFile)

            // Then — the stream should finish with authenticationRequired error
            let error = await #expect(throws: DownloadError.self) {
                for try await _ in stream {}
            }
            #expect(error == .authenticationRequired)

            // The error page file should have been cleaned up
            #expect(!fileManager.fileExists(atPath: srcFile.path))
        }
    }

    @Test("AccessDenied string triggers error page detection")
    func testDidFinishDownloadingTo_detectsAccessDenied() async throws {
        try await withTempDirectory { tempDir in
            // Given — a small file containing "AccessDenied"
            let srcFile = tempDir.appendingPathComponent("access_denied.txt")
            let content = "AccessDenied"
            try content.data(using: .utf8)!.write(to: srcFile)

            let dstFile = tempDir.appendingPathComponent("destination.xip")
            let (delegate, stream) = makeDelegate(dstPath: dstFile)

            let session = URLSession(configuration: .ephemeral)
            defer { session.invalidateAndCancel() }

            // When
            let dummyTask = session.downloadTask(with: URL(string: "https://example.com")!)
            delegate.urlSession(session, downloadTask: dummyTask, didFinishDownloadingTo: srcFile)

            // Then — should throw authenticationRequired
            let error = await #expect(throws: DownloadError.self) {
                for try await _ in stream {}
            }
            #expect(error == .authenticationRequired)
        }
    }

    @Test("Sign in page triggers error page detection")
    func testDidFinishDownloadingTo_detectsSignInPage() async throws {
        try await withTempDirectory { tempDir in
            // Given — a small file containing Apple sign-in page marker
            let srcFile = tempDir.appendingPathComponent("signin_page.html")
            let content = "<html>Sign in to your Apple Account</html>"
            try content.data(using: .utf8)!.write(to: srcFile)

            let dstFile = tempDir.appendingPathComponent("destination.xip")
            let (delegate, stream) = makeDelegate(dstPath: dstFile)

            let session = URLSession(configuration: .ephemeral)
            defer { session.invalidateAndCancel() }

            // When
            let dummyTask = session.downloadTask(with: URL(string: "https://example.com")!)
            delegate.urlSession(session, downloadTask: dummyTask, didFinishDownloadingTo: srcFile)

            // Then — should throw authenticationRequired
            let error = await #expect(throws: DownloadError.self) {
                for try await _ in stream {}
            }
            #expect(error == .authenticationRequired)
        }
    }

    @Test("File move failure propagates error through stream")
    func testDidFinishDownloadingTo_moveFailure() async throws {
        try await withTempDirectory { tempDir in
            // Given — a source file and a file handler that will fail on move
            let srcFile = tempDir.appendingPathComponent("source.xip")
            let paddedContent = String(repeating: "x", count: 10_001)
            try paddedContent.data(using: .utf8)!.write(to: srcFile)

            let dstFile = tempDir.appendingPathComponent("destination.xip")
            let mockFileHandler = MockedFileHandler()
            let moveError = NSError(domain: "test", code: 42, userInfo: [NSLocalizedDescriptionKey: "disk full"])
            mockFileHandler.nextMoveError = moveError

            let (delegate, stream) = makeDelegate(dstPath: dstFile, fileHandler: mockFileHandler)

            let session = URLSession(configuration: .ephemeral)
            defer { session.invalidateAndCancel() }

            // When — call didFinishDownloadingTo
            let dummyTask = session.downloadTask(with: URL(string: "https://example.com")!)
            delegate.urlSession(session, downloadTask: dummyTask, didFinishDownloadingTo: srcFile)

            // Then — the stream should finish with the move error
            let error = await #expect(throws: NSError.self) {
                for try await _ in stream {}
            }
            #expect(error?.domain == "test")
            #expect(error?.code == 42)
        }
    }
}

// MARK: - didCompleteWithError Tests
extension DownloadDelegateTests {

    @Test("didCompleteWithError with error finishes stream with that error")
    func testDidCompleteWithError_withError() async throws {
        // Given
        let dstFile = URL(fileURLWithPath: "/tmp/test_destination.xip")
        let (delegate, stream) = makeDelegate(dstPath: dstFile)

        let session = URLSession(configuration: .ephemeral)
        defer { session.invalidateAndCancel() }

        let downloadError = NSError(domain: NSURLErrorDomain, code: NSURLErrorTimedOut, userInfo: nil)

        // When — call didCompleteWithError with an error
        let dummyTask = session.downloadTask(with: URL(string: "https://example.com")!)
        delegate.urlSession(session, task: dummyTask, didCompleteWithError: downloadError)

        // Then — the stream should finish with that error
        let error = await #expect(throws: NSError.self) {
            for try await _ in stream {}
        }
        #expect(error?.domain == NSURLErrorDomain)
        #expect(error?.code == NSURLErrorTimedOut)
    }

    @Test("didCompleteWithError with nil does not throw after successful download")
    func testDidCompleteWithError_withNil() async throws {
        try await withTempDirectory { tempDir in
            // Given — simulate the scenario where didFinishDownloadingTo already completed the stream
            let srcFile = tempDir.appendingPathComponent("source.xip")
            let paddedContent = String(repeating: "x", count: 10_001)
            try paddedContent.data(using: .utf8)!.write(to: srcFile)

            let dstFile = tempDir.appendingPathComponent("destination.xip")
            let (delegate, stream) = makeDelegate(dstPath: dstFile)

            let session = URLSession(configuration: .ephemeral)
            defer { session.invalidateAndCancel() }

            let dummyTask = session.downloadTask(with: URL(string: "https://example.com")!)

            // When — first call didFinishDownloadingTo (which calls continuation.finish()),
            // then call didCompleteWithError with nil (which should be a no-op)
            delegate.urlSession(session, downloadTask: dummyTask, didFinishDownloadingTo: srcFile)
            delegate.urlSession(session, task: dummyTask, didCompleteWithError: nil)

            // Then — the stream should complete without error
            await #expect(throws: Never.self) {
                for try await _ in stream {}
            }
        }
    }
}
