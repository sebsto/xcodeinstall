//
//  MockedUtilitiesClasses.swift
//  xcodeinstallTests
//
//  Created by Stormacq, Sebastien on 27/08/2022.
//

import CLIlib
import Foundation

@testable import xcodeinstall

// used to test Installer component (see InstallerTest)
class MockedFileHandler: FileHandlerProtocol {

    var moveSrc: URL? = nil
    var moveDst: URL? = nil
    var nextFileExist: Bool? = nil
    var nextFileCorrect: Bool? = nil

    func move(from src: URL, to dst: URL) throws {
        moveSrc = src
        moveDst = dst
    }
    func fileExists(file: URL, fileSize: Int) -> Bool {
        if let nextFileExist {
            return nextFileExist
        } else {
            return true
        }
    }
    func downloadedFiles() throws -> [String] {
        ["name.pkg", "name.dmg"]
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

class MockShell: AsyncShellProtocol {

    var command: String = ""

    func run(
        _ command: String,
        onCompletion: ((Process) -> Void)?,
        onOutput: ((String) -> Void)?,
        onError: ((String) -> Void)?
    ) throws -> Process {

        self.command = command

        let process = Process()
        let out = "out"
        let err = "err"
        if let onCompletion {
            onCompletion(process)
        }
        if let onOutput {
            onOutput(out)
        }
        if let onError {
            onError(err)
        }
        return process
    }

    func run(_ command: String) throws -> ShellOutput {
        self.command = command
        return ShellOutput(out: "out", err: "err", code: 0)
    }

}

class MockedProgressBar: CLIProgressBarProtocol {

    var isComplete = false
    var isClear = false
    var step = 0
    var total = 0
    var text = ""
    private var _defineCalled = false

    func define(animationType: CLIlib.ProgressBarType, message: String) {
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
