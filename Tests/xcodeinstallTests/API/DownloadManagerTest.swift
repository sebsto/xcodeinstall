import Foundation
import Testing

@testable import xcodeinstall

struct MockDownloadManager: DownloadManagerProtocol {
    var mockProgress: [DownloadProgress] = []
    var shouldFail = false

    func download(from url: URL) -> AsyncStream<DownloadProgress> {
        AsyncStream { continuation in
            if shouldFail {
                continuation.finish()
                return
            }

            for progress in mockProgress {
                continuation.yield(progress)
                // try? await Task.sleep(nanoseconds: 100_000_000)  // 0.1s delay
            }
            continuation.finish()
        }
    }
}

@Suite("DownloadManager")
struct DownloadManagerTest {
    @Test("Test Download Manager progress")
    func testDownloadManager() async throws {
        var mockManager = MockDownloadManager()
        let now = Date()
        mockManager.mockProgress = [
            DownloadProgress(bytesWritten: 25, totalBytes: 100, startTime: now),
            DownloadProgress(bytesWritten: 50, totalBytes: 100, startTime: now),
            DownloadProgress(bytesWritten: 100, totalBytes: 100, startTime: now),
        ]

        var receivedProgress: [DownloadProgress] = []
        for await progress in mockManager.download(from: URL(string: "test")!) {
            receivedProgress.append(progress)
        }

        #expect(receivedProgress.count == 3)
        #expect(receivedProgress.last?.percentage == 1.0)
    }
}
