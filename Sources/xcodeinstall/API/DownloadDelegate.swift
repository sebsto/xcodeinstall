//
//  DownloadDelegate.swift
//  xcodeinstall
//
//  Created by Stormacq, Sebastien on 17/08/2022.
//

import CLIlib
import Foundation

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

// delegate class to receive download progress
@MainActor
final class DownloadDelegate: NSObject, URLSessionDownloadDelegate {

    var env: Environment
    let dstFilePath: URL?
    let totalFileSize: Int?
    let startTime: Date?

    // to notify the main thread when download is finish
    let sema: DispatchSemaphoreProtocol

    init(
        env: Environment,
        dstFilePath: URL? = nil,
        totalFileSize: Int? = nil,
        startTime: Date? = nil,
        semaphore: DispatchSemaphoreProtocol
    ) {
        self.env = env
        self.dstFilePath = dstFilePath
        self.totalFileSize = totalFileSize
        self.startTime = startTime
        self.sema = semaphore
    }

    nonisolated func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        Task {
            await completeTransfer(from: location)
        }
    }

    func completeTransfer(from location: URL) async {
        // tell the progress bar that we're done
        self.env.progressBar.complete(success: true)

        guard let dst = dstFilePath else {
            log.warning("⚠️ No destination specified. I am keeping the file at \(location)")
            return
        }

        log.debug("Finished at \(location)\nMoving to \(dst)")

        // ignore the error here ? It is logged one level down. How to bring it up to the user ?
        // file handler is not isolated to MainActor, need to use Task
        let fh = env.fileHandler
        let _ = await Task { try? await fh.move(from: location, to: dst) }.value

        // tell the main thread that we're done
        _ = self.sema.signal()
    }

    nonisolated func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        Task {
            await updateTransfer(totalBytesWritten: totalBytesWritten)
        }
    }

    func updateTransfer(totalBytesWritten: Int64) async {
        guard let tfs = totalFileSize else {
            fatalError("Developer forgot to share the total file size")
        }

        var text = "\(totalBytesWritten/1024/1024) MB"

        // when a start time is specified, compute the bandwidth
        if let start = self.startTime {

            let dif: TimeInterval = 0 - start.timeIntervalSinceNow
            let bandwidth = Double(totalBytesWritten) / Double(dif) / 1024 / 1024

            text += String(format: " / %.2f MBs", bandwidth)
        }
        env.progressBar.update(
            step: Int(totalBytesWritten / 1024),
            total: Int(tfs / 1024),
            text: text
        )

    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest
    ) async -> URLRequest? {
        request
    }

    nonisolated func urlSession(_ session: URLSession, didBecomeInvalidWithError error: Error?) {
        Task {
            log.warning("error \(String(describing: error))")
            _ = await self.sema.signal()
        }
    }
}
