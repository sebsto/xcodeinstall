//
//  MockedUtilitiesClasses.swift
//  xcodeinstallTests
//
//  Created by Stormacq, Sebastien on 27/08/2022.
//

import Foundation

@testable import xcodeinstall

// used to test Installer component (see InstallerTest)
final class MockedFileHandler: FileHandlerProtocol, @unchecked Sendable {

    var moveSrc: URL? = nil
    var moveDst: URL? = nil
    var nextMoveError: Error? = nil
    var nextFileExist: Bool? = nil
    var nextFileCorrect: Bool? = nil

    func move(from src: URL, to dst: URL) throws {
        moveSrc = src
        moveDst = dst
        if let nextMoveError { throw nextMoveError }
    }
    func fileExists(file: URL, fileSize: Int) -> Bool {
        if let nextFileExist {
            return nextFileExist
        } else {
            return true
        }
    }
    var nextDownloadedFilesError: Error? = nil
    func downloadedFiles() throws -> [String] {
        if let nextDownloadedFilesError { throw nextDownloadedFilesError }
        return ["name.pkg", "name.dmg"]
    }

    func downloadDirectory() -> URL {
        baseFilePath()
    }

    func checkFileSize(file: URL, fileSize: Int) throws -> Bool {
        if let nextFileCorrect {
            return nextFileCorrect
        } else {
            return true
        }
    }

    func downloadFileURL(file: DownloadList.File) -> URL {
        URL(fileURLWithPath: downloadFilePath(file: file))
    }

    func downloadFilePath(file: DownloadList.File) -> String {
        "/download/\(file.filename)"
    }

    func saveDownloadList(list: DownloadList) throws -> DownloadList {
        let listData = try loadTestData(file: .downloadList)
        return try JSONDecoder().decode(DownloadList.self, from: listData)
    }

    func loadDownloadList() throws -> DownloadList {
        let listData = try loadTestData(file: .downloadList)
        return try JSONDecoder().decode(DownloadList.self, from: listData)
    }

    func baseFilePath() -> URL {
        URL(string: "file:///tmp")!
    }

    func baseFilePath() -> String {
        "/tmp"
    }
}

class MockedProgressBar: CLIProgressBarProtocol {

    var isComplete = false
    var isClear = false
    var step = 0
    var total = 0
    var text = ""
    private var _defineCalled = false

    func define(animationType: ProgressBarType, message: String) {
        _defineCalled = true
    }
    func defineCalled() -> Bool {
        let called = _defineCalled
        _defineCalled = false
        return called
    }

    func update(step: Int, total: Int, text: String) {
        self.step = step
        self.total = total
        self.text = text
    }

    func complete(success: Bool) {
        isComplete = success
    }

    func clear() {
        isClear = true
    }

}
