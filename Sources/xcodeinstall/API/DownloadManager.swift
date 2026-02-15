import Logging

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

protocol DownloadManagerProtocol: Sendable {
    func download(from url: URL) -> AsyncThrowingStream<DownloadProgress, Error>
}

struct DownloadTarget: Sendable {
    let totalFileSize: Int
    let dstFilePath: URL
    let startTime: Date

    init(totalFileSize: Int, dstFilePath: URL, startTime: Date = Date.now) {
        self.totalFileSize = totalFileSize
        self.dstFilePath = dstFilePath
        self.startTime = startTime
    }
}

struct DownloadProgress: Sendable {
    let bytesWritten: Int64
    let totalBytes: Int64
    let startTime: Date
    var percentage: Double { Double(bytesWritten) / Double(totalBytes) }
    var bandwidth: Double {
        let elapsed = 0 - startTime.timeIntervalSinceNow
        return elapsed > 0 ? Double(bytesWritten) / Double(elapsed) / 1024 / 1024 : 0
    }
}

struct DownloadManager {

    private let log: Logger

    public init(logger: Logger) {
        self.log = logger
    }

    /// Downloads a file, returning a stream of progress updates.
    ///
    /// Uses URLSession's optimized download task (not byte-by-byte streaming)
    /// for pure structured concurrency — no Task, no Task.detached.
    /// Progress is observed via KVO on the task's Progress object.
    /// The consumer's `for try await` drives the stream: each iteration
    /// receives a progress update from the KVO observer. The main actor
    /// suspends cooperatively at each await.
    func download(
        from url: String,
        target downloadTarget: DownloadTarget,
        secrets: SecretsHandlerProtocol,
        fileHandler: FileHandlerProtocol
    ) async throws -> AsyncThrowingStream<DownloadProgress, Error> {

        var headers: [String: String] = ["Accept": "*/*"]

        let cookies = try? await secrets.loadCookies()
        if let cookies {
            headers.merge(HTTPCookie.requestHeaderFields(with: cookies)) { (current, _) in current }
        } else {
            log.debug("⚠️ I could not load cookies")
            throw DownloadError.authenticationRequired
        }

        let request = self.request(for: url, withHeaders: headers)
        _log(request: request, to: log)

        let totalBytes = Int64(downloadTarget.totalFileSize)
        let dstPath = downloadTarget.dstFilePath
        let startTime = downloadTarget.startTime
        let capturedLog = self.log

        // The continuation-based stream: KVO progress callbacks and delegate
        // completion drive the stream. No Task needed — the URLSession download
        // task runs on its own background queue and feeds progress into the
        // continuation. The consumer pulls progress via `for try await`.
        return AsyncThrowingStream { continuation in

            let handler = DownloadDelegate(
                continuation: continuation,
                totalBytes: totalBytes,
                startTime: startTime,
                dstPath: dstPath,
                fileHandler: fileHandler,
                log: capturedLog
            )

            // Create a dedicated session with our delegate.
            // The session retains the delegate for its lifetime.
            let session = URLSession(
                configuration: .default,
                delegate: handler,
                delegateQueue: nil  // URLSession creates its own serial queue
            )

            let task = session.downloadTask(with: request)
            task.resume()

            continuation.onTermination = { _ in
                task.cancel()
                session.invalidateAndCancel()
            }
        }
    }

    internal func request(
        for url: String,
        method: HTTPVerb = .GET,
        withBody body: Data? = nil,
        withHeaders headers: [String: String]? = nil
    ) -> URLRequest {

        let url = URL(string: url)!
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue

        if let body {
            request.httpBody = body
        }

        if let headers {
            for (key, value) in headers {
                request.addValue(value, forHTTPHeaderField: key)
            }
        }

        return request
    }
}

/// Handles URLSessionDownloadTask completion and progress observation.
/// Bridges the delegate callbacks into an AsyncThrowingStream continuation.
///
/// The download is started via `downloadTask(with:)` which returns immediately.
/// Progress is observed via KVO (synchronous, no isolation issues).
/// Completion is handled via `urlSession(_:task:didCompleteWithError:)`.
/// File move is handled via `urlSession(_:downloadTask:didFinishDownloadingTo:)`.
///
/// All delegate methods are `nonisolated` — they run on URLSession's background
/// serial queue, not on MainActor. No async callbacks, no isolation conflicts.
private final class DownloadDelegate: NSObject,
    URLSessionDownloadDelegate 
{
    // Safety invariant: all properties are either:
    // - set once in init and never mutated (continuation, totalBytes, startTime, dstPath, fileHandler, log)
    // - only accessed from URLSession's serial delegate queue (progressObservation, tempFileURL)
    private let continuation: AsyncThrowingStream<DownloadProgress, Error>.Continuation
    private let totalBytes: Int64
    private let startTime: Date
    private let dstPath: URL
    private let fileHandler: FileHandlerProtocol
    private let log: Logger
    // Only accessed from URLSession's serial delegate queue — no data race.
    nonisolated(unsafe) private var progressObservation: NSKeyValueObservation?

    init(
        continuation: AsyncThrowingStream<DownloadProgress, Error>.Continuation,
        totalBytes: Int64,
        startTime: Date,
        dstPath: URL,
        fileHandler: FileHandlerProtocol,
        log: Logger
    ) {
        self.continuation = continuation
        self.totalBytes = totalBytes
        self.startTime = startTime
        self.dstPath = dstPath
        self.fileHandler = fileHandler
        self.log = log
        super.init()
    }

    // Called synchronously when the task is created — sets up KVO progress observation.
    func urlSession(_ session: URLSession, didCreateTask task: URLSessionTask) {
        let cont = continuation
        let total = totalBytes
        let start = startTime
        progressObservation = task.progress.observe(\.fractionCompleted, options: [.new]) { _, change in
            if let fraction = change.newValue {
                let written = Int64(fraction * Double(total))
                cont.yield(
                    DownloadProgress(bytesWritten: written, totalBytes: total, startTime: start)
                )
            }
        }
    }

    // Called when the download file is ready — save the temp URL for moving.
    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        log.debug("HTTP response: \(downloadTask.response.map { ($0 as? HTTPURLResponse)?.statusCode ?? -1 } ?? -1)")

        // Check for error pages in small downloads
        let attrs = try? FileManager.default.attributesOfItem(atPath: location.path)
        let fileSize = (attrs?[.size] as? Int64) ?? 0
        if fileSize < 10_000 {
            if let data = try? Data(contentsOf: location),
                let content = String(data: data, encoding: .utf8),
                content.contains("<Error>") || content.contains("AccessDenied")
                    || content.contains("Sign in to your Apple Account")
            {
                try? FileManager.default.removeItem(at: location)
                continuation.finish(throwing: DownloadError.authenticationRequired)
                return
            }
        }

        // Move the file to the destination
        do {
            try fileHandler.move(from: location, to: dstPath)
        } catch {
            log.error("🛑 Failed to move downloaded file: \(error)")
            continuation.finish(throwing: error)
            return
        }

        // No need to yield final progress here — KVO already emitted the 100% update.
        // Yielding again would cause the progress bar to render the final line twice.
        continuation.finish()
    }

    // Called when the task completes (success or failure).
    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: (any Error)?
    ) {
        progressObservation?.invalidate()
        progressObservation = nil

        if let error {
            log.error("🛑 Download error: \(error)")
            continuation.finish(throwing: error)
        }
        // If no error, didFinishDownloadingTo already handled completion.
    }
}
