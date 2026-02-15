//
//  List.swift
//  xcodeinstall
//
//  Created by Stormacq, Sebastien on 19/07/2022.
//

import CLIlib
import Logging

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

protocol AppleDownloaderProtocol: Sendable {
    func list(force: Bool) async throws -> DownloadList
    func download(file: DownloadList.File) async throws -> AsyncThrowingStream<DownloadProgress, Error>
}

class AppleDownloader: HTTPClient, AppleDownloaderProtocol {

    let fileHandler: FileHandlerProtocol
    let downloadManager: DownloadManager

    init(
        secrets: SecretsHandlerProtocol,
        urlSession: URLSessionProtocol,
        fileHandler: FileHandlerProtocol,
        downloadManager: DownloadManager,
        log: Logger
    ) {
        self.fileHandler = fileHandler
        self.downloadManager = downloadManager
        super.init(secrets: secrets, urlSession: urlSession, log: log)
    }

    func download(file: DownloadList.File) async throws -> AsyncThrowingStream<DownloadProgress, Error> {

        guard !file.remotePath.isEmpty,
            !file.filename.isEmpty,
            file.fileSize > 0
        else {
            log.error("🛑 Invalid file specification : \(file)")
            throw DownloadError.invalidFileSpec
        }

        let fileURL = "https://developer.apple.com/services-account/download?path=\(file.remotePath)"

        let filePath = await URL(fileURLWithPath: fileHandler.downloadFilePath(file: file))
        let downloadTarget = DownloadTarget(totalFileSize: file.fileSize, dstFilePath: filePath, startTime: Date.now)

        downloadManager.downloadTarget = downloadTarget
        downloadManager.secrets = self.secrets
        downloadManager.fileHandler = self.fileHandler

        return try await downloadManager.download(from: fileURL)
    }

}
