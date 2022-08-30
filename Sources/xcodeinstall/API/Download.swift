//
//  List.swift
//  xcodeinstall
//
//  Created by Stormacq, Sebastien on 19/07/2022.
//

import Foundation
import Logging

protocol AppleDownloaderProtocol {
    func list(force: Bool) async throws -> [DownloadList.Download]
    func download(file: DownloadList.File,
                  progressReport: ProgressUpdateProtocol) async throws -> URLSessionDownloadTaskProtocol?
}

class AppleDownloader: NetworkAgent, AppleDownloaderProtocol {

    // control the progress of the download
    // not private for testability
    var downloadTask: URLSessionDownloadTaskProtocol?
    var downloadDelegate: DownloadDelegate?

    // block until download is finished
    // https://stackoverflow.com/questions/30702387/using-nsurlsession-from-a-swift-command-line-program
    var sema: DispatchSemaphoreProtocol = DispatchSemaphore( value: 0 )

    // used by testing to inject an HTTPClient that use a mocked URL Session
    override init(client: HTTPClient, secrets: SecretsHandler, logger: Logger) {
        super.init(client: client, secrets: secrets, logger: logger)
    }

    // Ensure this class is initialized with a URLSession with download callbacks
    init(logger: Logger, secrets: SecretsHandler) {
        self.downloadDelegate = DownloadDelegate(semaphore: self.sema, logger: logger)
        let urlSession = URLSession(configuration: .default,
                                    delegate: downloadDelegate,
                                    delegateQueue: nil)
        let downloadClient = HTTPClient(session: urlSession)
        super.init(client: downloadClient, secrets: secrets, logger: logger)
    }

    func download(file: DownloadList.File,
                  progressReport: ProgressUpdateProtocol) async throws -> URLSessionDownloadTaskProtocol? {

        guard !file.remotePath.isEmpty,
              !file.filename.isEmpty ,
              file.fileSize > 0 else {
            logger.error("🛑 Invalid file specification : \(file)")
            throw DownloadError.invalidFileSpec
        }

        let fileURL = "https://developer.apple.com/services-account/download?path=\(file.remotePath)"

        // pass a progress update client to the download delegate to receive progress updates
        let fileHandler = FileHandler(logger: logger)
        self.downloadDelegate?.totalFileSize = file.fileSize
        self.downloadDelegate?.progressUpdate = progressReport
        self.downloadDelegate?.dstFilePath = fileHandler.downloadFilePath(file: file)
        self.downloadDelegate?.startTime = Date.now

        // make a call to start the download
        // first call, should send a redirect and an auth cookie
        self.downloadTask = try await downloadCall(url: fileURL, requestHeaders: ["Accept": "*/*"])
        if let dlt = self.downloadTask {
            dlt.resume()
            sema.wait()
        }

        // returns when the download is completed
        return self.downloadTask

    }

}
