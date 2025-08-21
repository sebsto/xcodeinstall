//
//  EnvironmentMock.swift
//
//
//  Created by Stormacq, Sebastien on 22/11/2022.
//

import CLIlib
import Foundation
@testable import Subprocess // to be able to call internal init() functions
#if canImport(System)
import System
#else
import SystemPackage
#endif

@testable import xcodeinstall

struct MockedEnvironment: xcodeinstall.Environment {

    var fileHandler: FileHandlerProtocol = MockedFileHandler()

    var display: DisplayProtocol = MockedDisplay()
    var readLine: ReadLineProtocol = MockedReadLine()
    var progressBar: CLIProgressBarProtocol = MockedProgressBar()

    // this has to be injected by the caller (it contains a reference to the env
    var secrets: SecretsHandlerProtocol? = nil
    var awsSDK: AWSSecretsHandlerSDKProtocol? = nil

    var authenticator: AppleAuthenticatorProtocol = MockedAppleAuthentication()
    var downloader: AppleDownloaderProtocol = MockedAppleDownloader()

    var urlSessionData: URLSessionProtocol = MockedURLSession()

    func urlSessionDownload(
        dstFilePath: URL? = nil,
        totalFileSize: Int? = nil,
        startTime: Date? = nil
    ) -> any xcodeinstall.URLSessionProtocol {
        self.urlSessionData
    }

}

@MainActor
final class MockedRunRecorder: InputProtocol, OutputProtocol {
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
//        print(lastExecutable?.description)
        return lastExecutable == nil || lastExecutable?.description.isEmpty == true
    }
    
}

extension MockedEnvironment {
    static var runRecorder = MockedRunRecorder()

    func run (
        _ executable: Executable,
        arguments: Arguments,
    ) async throws -> ShellOutput  {
        return try await run(executable,
                   arguments: arguments,
                   workingDirectory: nil
        )
    }
    func run (
        _ executable: Executable,
        arguments: Arguments,
        workingDirectory: FilePath?,
    ) async throws -> ShellOutput  {
        
        MockedEnvironment.runRecorder.lastExecutable = executable
        MockedEnvironment.runRecorder.lastArguments = arguments

        // Return a dummy CollectedResult
        return CollectedResult(
            processIdentifier: ProcessIdentifier(value: 9999),
            terminationStatus: TerminationStatus.exited(0),
            standardOutput: "mocked output",
            standardError: "mocked error",
        )
    }
}
