//
//  AsyncShell.swift
//  xcodeinstall
//
//  Created by Stormacq, Sebastien on 20/08/2022.
//

import Foundation
import Logging

protocol AsyncShellProtocol: ShellProtocol {
    func run(_ command: String,
             onCompletion: ((Process) -> Void)?,
             onOutput: ((String) -> Void)?,
             onError: ((String) -> Void)?
            ) throws -> Process
}

/// Asynchronously run a shell comman
/// You may provide a blok of code to be executed uppon termination or when data are available on the output stream
struct AsyncShell: AsyncShellProtocol {

    let logger: Logger?

    let outputPipe: Pipe
    let errorPipe: Pipe

    let processStdOut: FileHandleStream
    let processStdErr: FileHandleStream

    init() {
        logger = Log().defaultLogger

        outputPipe = Pipe()
        processStdOut = FileHandleStream(outputPipe.fileHandleForReading)

        errorPipe = Pipe()
        processStdErr = FileHandleStream(errorPipe.fileHandleForReading)
    }

    // swiftlint:disable line_length
    /// Run the given command with its argument using ZSH
    ///  - Parameters
    ///     - command: the shell command to run, including its parameters (ex: 'ls -al')
    ///     - onCompletion: a block of code to be executed when the process terminates
    ///     - onOuput: a block of code to be executed when data are available on the standard output stream of the process
    ///     - onError: a block of code to be executed when data are available on the standard error stream of the process
    ///  - Returns the Task launched.  (Should we abstract to a Process wrapper ?)
    // swiftlint:enable line_length
    func run(_ command: String,
             onCompletion: ((Process) -> Void)? = nil,
             onOutput: ((String) -> Void)? = nil,
             onError: ((String) -> Void)? = nil
            ) throws -> Process {

        // create a task
        let task = Process()

        task.standardOutput = outputPipe
        task.standardError  = errorPipe

        // when we receive a completion handler, assign it to the task
        if let onc = onCompletion {
            task.terminationHandler = onc
        }

        // when we receive an output handler, assign it to our stdOut FileHandleStream
        if let ono = onOutput {
            processStdOut.onStringOutput(ono)
        }

        // when we receive an error handler, assign it to our stdErr FileHandleStream
        if let one = onError {
            processStdErr.onStringOutput(one)
        }

        do {

            // launch the zsh shell and wait for completion
            task.arguments = ["-c", command]
            task.launchPath = "/bin/zsh"
            try task.run()

        } catch {
            logger?.error("🛑 Can not launch task : \(error)")
            throw error
        }

        // the caller must call waitUntilExit()
        return task

    }

    // sync runs the command and return stdOut and stdErr in one shot at the end
    func run(_ command: String) throws -> ShellOutput {

        var stdOutBuffer: String = ""
        var stdErrBuffer: String = ""
        var result: ShellOutput?

        let shell = AsyncShell()
        let process = try shell.run(command,
                                    onCompletion: { process in
            result = ShellOutput(out: stdOutBuffer, err: stdErrBuffer, code: process.terminationStatus)
        },
                                    onOutput: { string in
            stdOutBuffer += string
        },
                                    onError: { string in
            stdErrBuffer += string
        })

        process.waitUntilExit()

        guard let res = result else {
            fatalError("Process finished but there is no output!")
        }

        return res
    }
}
