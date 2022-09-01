//
//  FileManagerExtension.swift
//  xcodeinstall
//
//  Created by Stormacq, Sebastien on 20/08/2022.
//

import Foundation
import Logging

// the methods I want to mock for unit testing
protocol FileHandlerProtocol {
    func move(from src: URL, to dst: URL) throws
    func fileExists(filePath: String, fileSize: Int) -> Bool
    func checkFileSize(filePath: String, fileSize: Int) throws -> Bool
    func downloadedFiles() throws -> [String]
    func downloadFilePath(file: DownloadList.File) -> String
    func saveDownloadList(list: DownloadList) throws -> DownloadList
    func loadDownloadList() throws -> DownloadList
    func baseFilePath() -> URL
    func baseFilePath() -> String
}

enum FileHandlerError: Error {
    case fileDoesNotExist
    case noDownloadedList
}

struct FileHandler: FileHandlerProtocol {

    static let baseDirectory
           = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".xcodeinstall")
    static let downloadDirectory = baseDirectory.appendingPathComponent("download")
    static let downloadListPath = baseDirectory.appendingPathComponent("downloadList")

    let fm = FileManager.default // swiftlint:disable:this identifier_name

    let logger: Logger

    init(logger: Logger) {
        self.logger = logger
    }

    func baseFilePath() -> String {
        return baseFilePath().path
    }
    func baseFilePath() -> URL {

        // if base directory does not exist, create it
        if !fm.fileExists(atPath: FileHandler.baseDirectory.path) {
            do {
                try fm.createDirectory(at: FileHandler.baseDirectory, withIntermediateDirectories: true)
            } catch {
                logger.error("🛑 Can not create base directory : \(FileHandler.baseDirectory.path)\n\(error)")
            }
        }

        return FileHandler.baseDirectory
    }

    func move(from src: URL, to dst: URL) throws {
        do {
            if fm.fileExists(atPath: dst.path) {
                self.logger.debug("⚠️ File \(dst) exists, I am overwriting it")
                try fm.removeItem(atPath: dst.path)
            }

            let dstUrl = URL(fileURLWithPath: dst.path)
            try fm.moveItem(at: src, to: dstUrl)

        } catch {
            self.logger.error("🛑 Can not move file : \(error)")
            throw error
        }
    }

    func downloadFilePath(file: DownloadList.File) -> String {
        return downloadFilePath(file: file).path
    }
    func downloadFilePath(file: DownloadList.File) -> URL {

        // if download directory does not exist, create it
        if !fm.fileExists(atPath: FileHandler.downloadDirectory.path) {
            do {
                try fm.createDirectory(at: FileHandler.downloadDirectory, withIntermediateDirectories: true)
            } catch {
                logger.error("🛑 Can not create base directory : \(FileHandler.downloadDirectory.path)\n\(error)")
            }
        }
        return FileHandler.downloadDirectory.appendingPathComponent(file.filename)
    }

    /// Check if file exists and has correct size
    ///  - Parameters:
    ///     - filePath the path of the file to verify
    ///     - fileSize the expected size of the file (in bytes).
    ///  - Returns : true when the file exists and has the given size, false otherwise
    ///  - Throws:
    ///     - FileHandlerError.FileDoesNotExistswhen the file does not exists
    func checkFileSize(filePath: String, fileSize: Int) throws -> Bool {

        // file exists ?
        let exists = fm.fileExists(atPath: filePath)
        if !exists { throw  FileHandlerError.fileDoesNotExist }

        // file size ?
        let attributes = try? fm.attributesOfItem(atPath: filePath)
        let actualSize = attributes?[.size] as? Int

        // at this stage, we know the file exists, just check size now
        return actualSize == fileSize
    }

    /// Check if file exists and has correct size
    /// - Parameters:
    ///     - filePath the path of the file to verify
    ///     - fileSize the expected size of the file (in bytes).
    ///       when omited, file size is not checked
    func fileExists(filePath: String, fileSize: Int = 0) -> Bool {

        let fileExists = fm.fileExists(atPath: filePath)
        // does the file exists ?
        if !fileExists {
            return false
        }

        // is the file complete ?
        // use try! because I verified if file exists already
        let fileComplete = try? self.checkFileSize(filePath: filePath, fileSize: fileSize)

        return (fileSize > 0 ? fileComplete ?? false : fileExists)
    }

    func downloadedFiles() throws -> [String] {
        do {
            return try fm.contentsOfDirectory(atPath: FileHandler.downloadDirectory.path)
        } catch {
            logger.debug("\(error)")
            throw FileHandlerError.noDownloadedList
        }
    }

    func saveDownloadList(list: DownloadList) throws -> DownloadList {

        // save list
        let data = try JSONEncoder().encode(list)
        try data.write(to: FileHandler.downloadListPath)

        return list

    }

    func loadDownloadList() throws -> DownloadList {

        // read the raw file saved on disk
        let listData = try Data(contentsOf: FileHandler.downloadListPath)

        return try JSONDecoder().decode(DownloadList.self, from: listData)
    }
}
