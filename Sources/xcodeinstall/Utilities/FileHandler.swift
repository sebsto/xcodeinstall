//
//  FileManagerExtension.swift
//  xcodeinstall
//
//  Created by Stormacq, Sebastien on 20/08/2022.
//

import Foundation
import CLIlib

// the methods I want to mock for unit testing
protocol FileHandlerProtocol {
    func move(from src: URL, to dst: URL) throws
    func fileExists(file: URL, fileSize: Int) -> Bool
    func checkFileSize(file: URL, fileSize: Int) throws -> Bool
    func downloadedFiles() throws -> [String]
    func downloadedFilePath(file: AvailableDownloadList.Download.File) -> String
    func downloadedFileURL(file: AvailableDownloadList.Download.File) -> URL
    func saveDownloadList(downloadList: AvailableDownloadList) throws ->  AvailableDownloadList
    func loadDownloadList() throws -> AvailableDownloadList
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

    func baseFilePath() -> String {
        return baseFilePath().path
    }
    func baseFilePath() -> URL {

        // if base directory does not exist, create it
        if !fm.fileExists(atPath: FileHandler.baseDirectory.path) {
            do {
                try fm.createDirectory(at: FileHandler.baseDirectory, withIntermediateDirectories: true)
            } catch {
                log.error("🛑 Can not create base directory : \(FileHandler.baseDirectory.path)\n\(error)")
            }
        }

        return FileHandler.baseDirectory
    }

    func move(from src: URL, to dst: URL) throws {
        do {
            if fm.fileExists(atPath: dst.path) {
                log.debug("⚠️ File \(dst) exists, I am overwriting it")
                try fm.removeItem(atPath: dst.path)
            }

            let dstUrl = URL(fileURLWithPath: dst.path)
            try fm.moveItem(at: src, to: dstUrl)

        } catch {
            log.error("🛑 Can not move file : \(error)")
            throw error
        }
    }

    func downloadedFilePath(file: AvailableDownloadList.Download.File) -> String {
        return downloadedFileURL(file: file).path
    }
    func downloadedFileURL(file: AvailableDownloadList.Download.File) -> URL {

        // if download directory does not exist, create it
        if !fm.fileExists(atPath: FileHandler.downloadDirectory.path) {
            do {
                try fm.createDirectory(at: FileHandler.downloadDirectory, withIntermediateDirectories: true)
            } catch {
                log.error("🛑 Can not create base directory : \(FileHandler.downloadDirectory.path)\n\(error)")
            }
        }
        return FileHandler.downloadDirectory.appendingPathComponent(file.filename)
    }

    /// Check if file exists and has correct size
    ///  - Parameters:
    ///     - file the URl of the file to verify
    ///     - fileSize the expected size of the file (in bytes).
    ///  - Returns : true when the file exists and has the given size, false otherwise
    ///  - Throws:
    ///     - FileHandlerError.FileDoesNotExistswhen the file does not exists
    func checkFileSize(file: URL, fileSize: Int) throws -> Bool {

        let filePath = file.path
        
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
    ///     - file the URL of the file to verify
    ///     - fileSize the expected size of the file (in bytes).
    ///       when omited, file size is not checked
    func fileExists(file: URL, fileSize: Int = 0) -> Bool {

        let filePath = file.path

        let fileExists = fm.fileExists(atPath: filePath)
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
            return try fm.contentsOfDirectory(atPath: FileHandler.downloadDirectory.path)
        } catch {
            log.debug("\(error)")
            throw FileHandlerError.noDownloadedList
        }
    }

    func saveDownloadList(downloadList: AvailableDownloadList) throws -> AvailableDownloadList {

        // save list
        let data = try JSONEncoder().encode(downloadList.list)
        try data.write(to: FileHandler.downloadListPath)

        return downloadList

    }

    func loadDownloadList() throws -> AvailableDownloadList {

        // read the raw file saved on disk
        return try AvailableDownloadList(withFileURL: FileHandler.downloadListPath)
    }
}
