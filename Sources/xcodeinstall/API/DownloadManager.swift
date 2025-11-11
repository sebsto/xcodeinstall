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

class DownloadManager {

    var env: Environment? = nil
    var downloadTarget: DownloadTarget? = nil
    private let log: Logger

    public init(env: Environment? = nil, downloadTarget: DownloadTarget? = nil, logger: Logger) {
        self.env = env
        self.downloadTarget = downloadTarget
        self.log = logger
    }

    func download(from url: String) async throws -> AsyncThrowingStream<DownloadProgress, Error> {

        guard let downloadTarget = self.downloadTarget else {
            fatalError("Developer forgot to set the download target")
        }

        guard let env = self.env else {
            fatalError("Developer forgot to set the environment")
        }

        var request: URLRequest
        var headers: [String: String] = ["Accept": "*/*"]

        // reload cookies if they exist
        let cookies = try? await env.secrets!.loadCookies()
        if let cookies {
            // cookies existed, let's add them to our HTTPHeaders
            headers.merge(HTTPCookie.requestHeaderFields(with: cookies)) { (current, _) in current }
        } else {
            log.debug("⚠️ I could not load cookies")
            throw DownloadError.authenticationRequired
        }

        // build the request
        request = self.request(for: url, withHeaders: headers)
        _log(request: request, to: log)

        // create the download task, start it , and start streaming its progress
        return AsyncThrowingStream { continuation in
            let delegate = DownloadDelegate(
                target: downloadTarget,
                continuation: continuation,
                fileHandler: env.fileHandler,
                log: self.log
            )
            let session = URLSession(configuration: .default, delegate: delegate, delegateQueue: nil)
            let task = session.downloadTask(with: request)
            task.resume()
        }
    }

    // prepare an URLRequest for a given url, method, body, and headers
    // https://softwareengineering.stackexchange.com/questions/100959/how-do-you-unit-test-private-methods
    internal func request(
        for url: String,
        method: HTTPVerb = .GET,
        withBody body: Data? = nil,
        withHeaders headers: [String: String]? = nil
    ) -> URLRequest {

        // create the request
        let url = URL(string: url)!
        var request = URLRequest(url: url)

        // add HTTP verb
        request.httpMethod = method.rawValue

        // add body
        if let body {
            request.httpBody = body
        }

        // add headers
        if let headers {
            for (key, value) in headers {
                request.addValue(value, forHTTPHeaderField: key)
            }
        }

        return request
    }
}

// MARK: Download Delegate functions
final class DownloadDelegate: NSObject, URLSessionDownloadDelegate {

    private let downloadTarget: DownloadTarget
    private let continuation: AsyncThrowingStream<DownloadProgress, Error>.Continuation
    private let log: Logger
    private let fileHandler: FileHandlerProtocol
    init(
        target: DownloadTarget,
        continuation: AsyncThrowingStream<DownloadProgress, Error>.Continuation,
        fileHandler: FileHandlerProtocol,
        log: Logger
    ) {
        self.downloadTarget = target
        self.continuation = continuation
        self.log = log
        self.fileHandler = fileHandler
    }
    // URLSessionDownloadDelegate methods
    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        let total =
            totalBytesExpectedToWrite <= 0 ? Int64(self.downloadTarget.totalFileSize) : totalBytesExpectedToWrite
        let progress = DownloadProgress(
            bytesWritten: totalBytesWritten,
            totalBytes: total,
            startTime: self.downloadTarget.startTime
        )
        continuation.yield(progress)
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        do {
            // Check if the downloaded file contains an XML error
            if let data = try? Data(contentsOf: location),
                let content = String(data: data, encoding: .utf8),
                content.contains("<Error>") || content.contains("AccessDenied")
                    || content.contains("Sign in to your Apple Account")
            {
                throw DownloadError.authenticationRequired
            }

            let dst = self.downloadTarget.dstFilePath
            log.debug("Finished downloading at \(location)\nMoving to \(dst)")

            try self.fileHandler.move(from: location, to: dst)
            continuation.finish()

        } catch {
            log.error("🛑 Error moving downloaded file: \(error)")
            continuation.finish(throwing: error)
        }

    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest
    ) async -> URLRequest? {
        log.debug("Redirected")
        return request
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: (any Error)?) {
        if let e = error {
            log.error("Error when downloading : \(String(describing: error))")
            continuation.finish(throwing: e)
        }
    }

}
