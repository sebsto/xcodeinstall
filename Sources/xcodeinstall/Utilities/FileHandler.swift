//
//  FileManagerExtension.swift
//  xcodeinstall
//
//  Created by Stormacq, Sebastien on 20/08/2022.
//

import Logging

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

// the methods I want to mock for unit testing
protocol FileHandlerProtocol: Sendable {
    nonisolated func move(from src: URL, to dst: URL) throws
    func fileExists(file: URL, fileSize: Int) -> Bool
    func checkFileSize(file: URL, fileSize: Int) throws -> Bool
    func downloadedFiles() throws -> [String]
    func downloadFilePath(file: DownloadList.File) async -> String
    func downloadFileURL(file: DownloadList.File) async -> URL
    func saveDownloadList(list: DownloadList) throws -> DownloadList
    func loadDownloadList() throws -> DownloadList
    func baseFilePath() -> URL
    func baseFilePath() -> String
    func downloadDirectory() -> URL
}

enum FileHandlerError: Error {
    case fileDoesNotExist
    case noDownloadedList
}

struct FileHandler: FileHandlerProtocol {

    private let log: Logger
    init(log: Logger) {
        self.log = log
    }

    private static let baseDirectory = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".xcodeinstall")
    func downloadDirectory() -> URL { FileHandler.baseDirectory.appendingPathComponent("download") }
    func downloadListPath() -> URL { FileHandler.baseDirectory.appendingPathComponent("downloadList") }

    func baseFilePath() -> String {
        baseFilePath().path
    }
    func baseFilePath() -> URL {

        // if base directory does not exist, create it
        let fm = FileManager.default  // swiftlint:disable:this identifier_name
        if !fm.fileExists(atPath: FileHandler.baseDirectory.path) {
            do {
                try FileManager.default.createDirectory(at: downloadDirectory(), withIntermediateDirectories: true)
            } catch {
                log.error("🛑 Can not create base directory : \(FileHandler.baseDirectory.path)\n\(error)")
            }
        }

        return FileHandler.baseDirectory
    }

    nonisolated func move(from src: URL, to dst: URL) throws {
        do {
            if FileManager.default.fileExists(atPath: dst.path) {
                log.debug("⚠️ File \(dst) exists, I am overwriting it")
                try FileManager.default.removeItem(atPath: dst.path)
            }

            let dstUrl = URL(fileURLWithPath: dst.path)
            try FileManager.default.moveItem(at: src, to: dstUrl)

        } catch {
            log.error("🛑 Can not move file : \(error)")
            throw error
        }
    }

    func downloadFilePath(file: DownloadList.File) async -> String {
        await downloadFileURL(file: file).path
    }
    func downloadFileURL(file: DownloadList.File) async -> URL {

        // if download directory does not exist, create it
        if !FileManager.default.fileExists(atPath: downloadDirectory().path) {
            do {
                try FileManager.default.createDirectory(at: downloadDirectory(), withIntermediateDirectories: true)
            } catch {
                log.error(
                    "🛑 Can not create base directory : \(downloadDirectory().path)\n\(error)"
                )
            }
        }
        return downloadDirectory().appendingPathComponent(file.filename)

    }

    /// Check if file exists and has correct size
    ///  - Parameters:
    ///     - filePath the path of the file to verify
    ///     - fileSize the expected size of the file (in bytes).
    ///  - Returns : true when the file exists and has the given size, false otherwise
    ///  - Throws:
    ///     - FileHandlerError.FileDoesNotExist when the file does not exists
    func checkFileSize(file: URL, fileSize: Int) throws -> Bool {

        let filePath = file.path

        // file exists ?
        let exists = FileManager.default.fileExists(atPath: filePath)
        if !exists { throw FileHandlerError.fileDoesNotExist }

        // file size ?
        let attributes = try? FileManager.default.attributesOfItem(atPath: filePath)
        let actualSize = attributes?[.size] as? Int

        // at this stage, we know the file exists, just check size now
        return actualSize == fileSize
    }

    /// Check if file exists and has correct size
    /// - Parameters:
    ///     - filePath the path of the file to verify
    ///     - fileSize the expected size of the file (in bytes).
    ///       when omited, file size is not checked
    func fileExists(file: URL, fileSize: Int = 0) -> Bool {

        let filePath = file.path

        let fileExists = FileManager.default.fileExists(atPath: filePath)
        // does the file exists ?
        if !fileExists {
            return false
        }

        // is the file complete ?
        // use try! because I verified if file exists already
        let fileComplete = try? self.checkFileSize(file: file, fileSize: fileSize)

        return (fileSize > 0 ? fileComplete ?? false : fileExists)
    }

    func downloadedFiles() throws -> [String] {
        do {
            return try FileManager.default.contentsOfDirectory(atPath: downloadDirectory().path)
        } catch {
            log.debug("\(error)")
            throw FileHandlerError.noDownloadedList
        }
    }

    func saveDownloadList(list: DownloadList) throws -> DownloadList {

        // ensure base directory exists before saving
        let _: URL = baseFilePath()

        // save list
        let data = try JSONEncoder().encode(list)
        try data.write(to: downloadListPath())

        return list

    }

    func loadDownloadList() throws -> DownloadList {

        // read the raw file saved on disk
        let listData = try Data(contentsOf: downloadListPath())

        return try JSONDecoder().decode(DownloadList.self, from: listData)
    }
}
