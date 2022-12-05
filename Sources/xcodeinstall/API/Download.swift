//
//  List.swift
//  xcodeinstall
//
//  Created by Stormacq, Sebastien on 19/07/2022.
//

import Foundation
import CLIlib

protocol AppleDownloaderProtocol {
    func list(force: Bool) async throws -> DownloadList
    func download(file: DownloadList.File) async throws -> URLSessionDownloadTaskProtocol?
}

class AppleDownloader: HTTPClient, AppleDownloaderProtocol {
    
    // control the progress of the download
    // not private for testability
    var downloadTask: URLSessionDownloadTaskProtocol?

    func download(file: DownloadList.File) async throws -> URLSessionDownloadTaskProtocol? {

        guard let downloadDelegate = env.urlSessionDownload.downloadDelegate() else {
            fatalError("This method requires an injected download delegate")
        }
        
        guard !file.remotePath.isEmpty,
              !file.filename.isEmpty,
              file.fileSize > 0 else {
            log.error("🛑 Invalid file specification : \(file)")
            throw DownloadError.invalidFileSpec
        }

        let fileURL = "https://developer.apple.com/services-account/download?path=\(file.remotePath)"

        // pass a progress update client to the download delegate to receive progress updates
        downloadDelegate.totalFileSize = file.fileSize
        downloadDelegate.dstFilePath = URL(fileURLWithPath: env.fileHandler.downloadFilePath(file: file))
        downloadDelegate.startTime = Date.now

        // make a call to start the download
        // first call, should send a redirect and an auth cookie
        self.downloadTask = try await downloadCall(url: fileURL, requestHeaders: ["Accept": "*/*"])
        if let dlt = self.downloadTask {
            dlt.resume()
            downloadDelegate.sema.wait()
        }

        // returns when the download is completed
        return self.downloadTask

    }

}
