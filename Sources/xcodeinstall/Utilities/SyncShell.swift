//
//  Shell.swift
//  xcodeinstall
//
//  Created by Stormacq, Sebastien on 25/07/2022.
//

import Foundation
import Logging

struct ShellOutput {
    var out: String?
    var err: String?
    var code: Int32
}

enum ShellError: Error {
    case fileDoesNotExist(filePath: String, fileSize: Int)
}

protocol ShellProtocol {
    func run(_ command: String) throws -> ShellOutput
}

struct SyncShell: ShellProtocol {

    let logger: Logger?

    init() {
        logger = Log().defaultLogger
    }

    func run(_ command: String) throws -> ShellOutput {

        // create a task
        let task = Process()

        // create a pipe to read stdin and stdout
        let pipeOut = Pipe()
        let pipeErr = Pipe()

        // assign the pipe to std i/o of the process
        task.standardOutput = pipeOut
        task.standardError = pipeErr

        // launch the zsh shell and wait for completion
        task.arguments = ["-c", command]
        task.launchPath = "/bin/zsh"
        task.launch()
        task.waitUntilExit()

        do {

            // capture standard out and standard err
            var output: String?
            if let data = try pipeOut.fileHandleForReading.readToEnd() {
                output = String(data: data, encoding: .utf8)
            }

            var error: String?
            if let dataErr = try pipeErr.fileHandleForReading.readToEnd() {
                error = String(data: dataErr, encoding: .utf8)
            }
            return ShellOutput(out: output, err: error, code: task.terminationStatus)

        } catch {
            logger?.error("🛑 Can not read stdout or stderr : \(error)")
            throw error
        }

    }
}
