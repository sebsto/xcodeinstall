import Foundation
import Logging

protocol DownloadManagerProtocol: Sendable {
    func download(from url: URL) -> AsyncStream<DownloadProgress>
}

@MainActor
class DownloadManager: NSObject, URLSessionDownloadDelegate {

    let log: Logger
    public init(logger: Logger) {
        self.log = logger
    }
    private var continuation: AsyncStream<DownloadProgress>.Continuation?

    func download(from url: URL) -> AsyncStream<DownloadProgress> {
        AsyncStream { continuation in
            self.continuation = continuation

            let session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
            let task = session.downloadTask(with: url)
            task.resume()
        }
    }

    // URLSessionDownloadDelegate methods
    nonisolated func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        let progress = DownloadProgress(
            bytesWritten: totalBytesWritten,
            totalBytes: totalBytesExpectedToWrite
        )
        Task { await continuation?.yield(progress) }
    }

    nonisolated func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {

        do {
            let destinationURL = URL(fileURLWithPath: "/path/to/save/file.zip")

            // Create directory if it doesn't exist
            try FileManager.default.createDirectory(
                at: destinationURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )

            // Move file from temporary location to final destination
            try FileManager.default.moveItem(at: location, to: destinationURL)

        } catch {
            log.error("🛑 Error moving downloaded file: \(error)")
        }
        Task { await continuation?.finish() }
    }
}

struct DownloadProgress: Sendable {
    let bytesWritten: Int64
    let totalBytes: Int64
    var percentage: Double { Double(bytesWritten) / Double(totalBytes) }
}
