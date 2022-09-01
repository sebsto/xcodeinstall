//
//  DownloadDelegate.swift
//  xcodeinstall
//
//  Created by Stormacq, Sebastien on 17/08/2022.
//

import Foundation
import Logging

// delegate class to receive download progress
class DownloadDelegate: NSObject, URLSessionDownloadDelegate {

    var fileHandler: FileHandlerProtocol
    var progressUpdate: ProgressUpdateProtocol?
    var dstFilePath: URL?
    var totalFileSize: Int?
    var startTime: Date?
    let logger: Logger

    // to notify the main thread when download is finish
    private let sema: DispatchSemaphoreProtocol
    init(semaphore: DispatchSemaphoreProtocol, fileHandler: FileHandlerProtocol, logger: Logger) {
        self.sema = semaphore
        self.fileHandler = fileHandler
        self.logger = logger
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        completeTransfer(from: location)
    }

    func completeTransfer(from location: URL) {
        // tell the progress bar that we're done
        self.progressUpdate?.complete(success: true)

        guard let dst = dstFilePath else {
            logger.warning("⚠️ No destination specified. I am keeping the file at \(location)")
            return
        }

        logger.debug("Finished at \(location)\nMoving to \(dst)")

        // ignore the error here ? It is logged one level down. How to bring it up to the user ?
        try? self.fileHandler.move(from: location, to: dst)

        // tell the main thread that we're done
        _ = self.sema.signal()
    }

    func urlSession(_ session: URLSession,
                    downloadTask: URLSessionDownloadTask,
                    didWriteData bytesWritten: Int64,
                    totalBytesWritten: Int64,
                    totalBytesExpectedToWrite: Int64) {
        updateTransfer(totalBytesWritten: totalBytesWritten)
    }

    func updateTransfer(totalBytesWritten: Int64) {
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
        self.progressUpdate?.update(step: Int(totalBytesWritten/1024),
                                    total: Int(tfs/1024),
                                    text: text)

    }

    func urlSession(_ session: URLSession,
                    task: URLSessionTask,
                    willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest) async -> URLRequest? {
        return request
    }

    func urlSession(_ session: URLSession, didBecomeInvalidWithError error: Error?) {
        logger.warning("error \(String(describing: error))")
        _ = self.sema.signal()
    }
}
