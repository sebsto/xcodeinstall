//
//  List.swift
//  xcodeinstall
//
//  Created by Stormacq, Sebastien on 19/07/2022.
//

import CLIlib

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

    func download(file: DownloadList.File) async throws -> AsyncThrowingStream<DownloadProgress, Error> {

        guard !file.remotePath.isEmpty,
            !file.filename.isEmpty,
            file.fileSize > 0
        else {
            log.error("🛑 Invalid file specification : \(file)")
            throw DownloadError.invalidFileSpec
        }

        let fileURL = "https://developer.apple.com/services-account/download?path=\(file.remotePath)"

        let fh = self.env().fileHandler
        let filePath = await URL(fileURLWithPath: fh.downloadFilePath(file: file))
        let downloadTarget = DownloadTarget(totalFileSize: file.fileSize, dstFilePath: filePath, startTime: Date.now)

        let downloadManager = self.env().downloadManager
        downloadManager.downloadTarget = downloadTarget
        downloadManager.env = self.env()

        return try await downloadManager.download(from: fileURL)
    }

}
