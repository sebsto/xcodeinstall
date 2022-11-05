//
//  AppleDownloadDelegate.swift
//  
//
//  Created by Stormacq, Sebastien on 22/10/2022.
//

import Foundation
import CLIlib

typealias CompletionCallback = (Result<URL, Error>) -> Void

// delegate class to receive download progress
class AppleDownloadDelegate: NSObject, URLSessionDownloadDelegate {

    // to update User Interface
    var progressUpdate: ProgressUpdateProtocol?
    var totalFileSize: Int64?
    var startTime: Date?
    
    // the destination of the file
    var dstFile : URL?

    // to notify the main thread when download is finish
    // see https://stackoverflow.com/questions/73664619/how-to-correctly-await-a-swift-callback-closure-result 
    var callback: CompletionCallback?
    
    //MARK: Completed
    //
    // download completed with no error
    //
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        guard let progress = self.progressUpdate,
              let callback = self.callback,
              let dstFile  = self.dstFile else {
            fatalError("Pass a progress update, callback reference and destination file URL to use this class")
        }
        
        log.debug("Finished at \(location)\nMoving to \(dstFile)")

        // tell the progress bar that we're done
        progress.complete(success: true)
        
        // ignore the error here ? It is logged one level down. How to bring it up to the user ?
        try? env.fileHandler.move(from: location, to: dstFile)

        // tell the main thread that we're done
        callback(.success(dstFile))
    }

    //MARK: In Progress
    //
    // download in progress
    //
    func urlSession(_ session: URLSession,
                    downloadTask: URLSessionDownloadTask,
                    didWriteData bytesWritten: Int64,
                    totalBytesWritten: Int64,
                    totalBytesExpectedToWrite: Int64) {

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

    //MARK: Redirection
    //
    // server asked to redirect
    //
    func urlSession(_ session: URLSession,
                    task: URLSessionTask,
                    willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest) async -> URLRequest? {
        return request
    }

    //MARK: Error
    //
    // download ended with an error
    //
    func urlSession(_ session: URLSession, didBecomeInvalidWithError error: Error?) {
        guard let progress = self.progressUpdate,
              let callback = self.callback else {
            fatalError("Pass a progress update and callback reference to use this class")
        }

        log.warning("error \(String(describing: error))")
        
        // tell the progress bar that we're done
        progress.complete(success: false)

        
        if let error {
            callback(.failure(error))
        } else {
            callback(.failure(AppleAPIError.unknownError))
        }
    }
}

