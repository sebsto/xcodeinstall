//
//  MockedUtilitiesClasses.swift
//  xcodeinstallTests
//
//  Created by Stormacq, Sebastien on 27/08/2022.
//

import Foundation
import CLIlib
@testable import xcodeinstall

func loadAvailableDownloadFromTestFile() throws -> AvailableDownloadList {
    // load list from file
    // https://stackoverflow.com/questions/47177036/use-resources-in-unit-tests-with-swift-package-manager
    let filePath = Bundle.module.path(forResource: "available-downloads", ofType: "json")!
//    let filePath = MyBundle.module.path(forResource: "available-downloads", ofType: "json")!
    let fileURL = URL(fileURLWithPath: filePath)
    return try AvailableDownloadList(withFileURL: fileURL)
    
}


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
        return ["name.pkg", "name.dmg", "name.app"]
    }

    func checkFileSize(file: URL, fileSize: Int) throws -> Bool {
        if let nextFileCorrect {
            return nextFileCorrect
        } else {
            return true
        }
    }
    
    func downloadedFilePath(file: AvailableDownloadList.Download.File) -> String {
        return "/download/\(file.filename)"
    }
    
    func downloadedFileURL(file: AvailableDownloadList.Download.File) -> URL {
        return URL(fileURLWithPath: "/download/\(file.filename)")
    }

    func saveDownloadList(downloadList: AvailableDownloadList) throws -> AvailableDownloadList {
        return try loadAvailableDownloadFromTestFile()
    }
    
    func loadDownloadList() throws -> AvailableDownloadList {
        return try loadAvailableDownloadFromTestFile()
    }
    
    func baseFilePath() -> URL {
        return URL(string: "file:///not_implemented.tmp")!
    }
    
    func baseFilePath() -> String {
        return "not_implemented.tmp"
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
    var isSuccess  = false
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
        isSuccess = success
        isComplete = true
    }

    func clear() {
        isClear = true
    }

}
