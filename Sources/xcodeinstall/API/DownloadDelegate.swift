//
//  DownloadDelegate.swift
//  xcodeinstall
//
//  Created by Stormacq, Sebastien on 17/08/2022.
//

import CLIlib
import Foundation
import Logging

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

// delegate class to receive download progress
@MainActor
final class DownloadDelegate: NSObject, URLSessionDownloadDelegate {

    let log: Logger
    var environment: Environment?

    var dstFilePath: URL? = nil
    var totalFileSize: Int? = nil
    var startTime: Date? = nil

    // to notify the main thread when download is finish
    let sema: DispatchSemaphoreProtocol

    init(
        semaphore: DispatchSemaphoreProtocol,
        log: Logger
    ) {
        self.log = log
        self.sema = semaphore
    }
    func env() -> Environment {
        guard let e = self.environment else {
            fatalError("Developer forgot to set the environment")
        }
        return e
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
        self.env().progressBar.complete(success: true)

        guard let dst = dstFilePath else {
            log.warning("⚠️ No destination specified. I am keeping the file at \(location)")
            return
        }

        log.debug("Finished at \(location)\nMoving to \(dst)")

        // ignore the error here ? It is logged one level down. How to bring it up to the user ?
        let fh = env().fileHandler
        let _ = try? await fh.move(from: location, to: dst)

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
        env().progressBar.update(
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
