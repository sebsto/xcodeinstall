//
//  MockedUtilitiesClasses.swift
//  xcodeinstallTests
//
//  Created by Stormacq, Sebastien on 27/08/2022.
//

import Foundation
import CLIlib
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
        return ["name.pkg", "name.dmg"]
    }

    func checkFileSize(file: URL, fileSize: Int) throws -> Bool {
        if let nextFileCorrect {
            return nextFileCorrect
        } else {
            return true
        }
    }
    
    func downloadFileURL(file: DownloadList.File) -> URL {
        return URL(fileURLWithPath: downloadFilePath(file: file))
    }

    func downloadFilePath(file: DownloadList.File) -> String {
        return "/download/\(file.filename)"
    }
    
    func saveDownloadList(list: DownloadList) throws -> DownloadList {
        let filePath = testDataDirectory().appendingPathComponent("Download List.json");
        let listData = try Data(contentsOf: filePath)
        return try JSONDecoder().decode(DownloadList.self, from: listData)
    }
    
    func loadDownloadList() throws -> DownloadList {
        let filePath = testDataDirectory().appendingPathComponent("Download List.json");
        let listData = try Data(contentsOf: filePath)
        return try JSONDecoder().decode(DownloadList.self, from: listData)
    }
    
    func baseFilePath() -> URL {
        return URL(string: "file:///tmp")!
    }
    
    func baseFilePath() -> String {
        return "/tmp"
    }
}

class MockShell: AsyncShellProtocol {

    var command: String = ""

    func run(_ command: String,
             onCompletion: ((Process) -> Void)?,
             onOutput: ((String) -> Void)?,
             onError: ((String) -> Void)?) throws -> Process {

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

class MockedProgressBar: ProgressUpdateProtocol {

    var isComplete = false
    var isClear    = false
    var step  = 0
    var total = 0
    var text  = ""

    func update(step: Int, total: Int, text: String) {
        self.step  = step
        self.total = total
        self.text  = text
    }

    func complete(success: Bool) {
        isComplete = success
    }

    func clear() {
        isClear = true
    }

}
