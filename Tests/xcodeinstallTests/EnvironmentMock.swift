//
//  EnvironmentMock.swift
//
//
//  Created by Stormacq, Sebastien on 22/11/2022.
//

import Foundation
import Logging

@testable import Subprocess  // to be able to call internal init() functions
@testable import xcodeinstall

#if canImport(System)
import System
#else
import SystemPackage
#endif

// MARK: - MockedShell for recording shell calls in tests

@MainActor
final class MockedShell: ShellExecuting {
    static var runRecorder = MockedRunRecorder()
    var nextError: Error? = nil

    nonisolated func run(
        _ executable: Executable,
        arguments: Arguments
    ) async throws -> ShellOutput {
        try await run(executable, arguments: arguments, workingDirectory: nil)
    }

    nonisolated func run(
        _ executable: Executable,
        arguments: Arguments,
        workingDirectory: FilePath?
    ) async throws -> ShellOutput {
        let error = await MainActor.run {
            MockedShell.runRecorder.lastExecutable = executable
            MockedShell.runRecorder.lastArguments = arguments
            return self.nextError
        }

        if let error {
            throw error
        }

        return CollectedResult(
            processIdentifier: ProcessIdentifier(value: 9999),
            terminationStatus: TerminationStatus.exited(0),
            standardOutput: "mocked output",
            standardError: "mocked error"
        )
    }
}

struct MockedRunRecorder: InputProtocol, OutputProtocol {
    func write(with writer: Subprocess.StandardInputWriter) async throws {

    }

    var lastExecutable: Executable?
    var lastArguments: Arguments = []

    func containsExecutable(_ command: String) -> Bool {
        lastExecutable?.description.contains(command) ?? false
    }
    func containsArgument(_ argument: String) -> Bool {
        lastArguments.description.contains(argument)
    }
    func isEmpty() -> Bool {
        lastExecutable == nil || lastExecutable?.description.isEmpty == true
    }
}

// MARK: - MockedEnvironment convenience wrapper

// this is our builder for test fixtures
@MainActor
final class MockedEnvironment {

    let fileHandler: FileHandlerProtocol
    var display: DisplayProtocol
    var readLine: ReadLineProtocol
    var progressBar: CLIProgressBarProtocol
    var secrets: SecretsHandlerProtocol?
    var authenticator: AppleAuthenticatorProtocol
    var urlSessionData: URLSessionProtocol
    let shell: MockedShell

    init(
        fileHandler: FileHandlerProtocol = MockedFileHandler(),
        readLine: ReadLineProtocol = MockedReadLine([]),
        progressBar: CLIProgressBarProtocol = MockedProgressBar()
    ) {
        self.fileHandler = fileHandler
        self.readLine = readLine
        self.progressBar = progressBar
        self.display = MockedDisplay()
        self.authenticator = MockedAppleAuthentication()
        self.urlSessionData = MockedURLSession()
        self.shell = MockedShell()
    }

    var downloader: MockedAppleDownloader = MockedAppleDownloader()

    var urlSessionDownload: URLSessionProtocol {
        self.urlSessionData
    }

    /// Build an AppDependencies from this mock's current state
    func toDeps(log: Logger = Logger(label: "test")) -> AppDependencies {
        AppDependencies(
            fileHandler: self.fileHandler,
            display: self.display,
            readLine: self.readLine,
            progressBar: self.progressBar,
            secrets: self.secrets,
            authenticator: self.authenticator,
            downloader: self.downloader,
            urlSessionData: self.urlSessionData,
            shell: self.shell,
            log: log
        )
    }
}
