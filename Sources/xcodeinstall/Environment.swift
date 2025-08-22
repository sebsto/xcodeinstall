//
//  Environment.swift
//
//
//  Created by Stormacq, Sebastien on 22/11/2022.
//

import CLIlib
import Foundation
import Logging
import Subprocess
#if canImport(System)
import System
#else
import SystemPackage
#endif

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/**

 a global struct to give access to classes for which I wrote tests.
 this global object allows me to simplify dependency injection */

@MainActor
protocol Environment: Sendable {
    var fileHandler: FileHandlerProtocol { get }
    var display: DisplayProtocol { get }
    var readLine: ReadLineProtocol { get }
    var progressBar: CLIProgressBarProtocol { get }
    var secrets: SecretsHandlerProtocol? { get set }
    var authenticator: AppleAuthenticatorProtocol { get }
    var downloader: AppleDownloaderProtocol { get }
    var urlSessionData: URLSessionProtocol { get }
    func urlSessionDownload(dstFilePath: URL?, totalFileSize: Int?, startTime: Date?) -> URLSessionProtocol
    func run(
        _ executable: Executable,
        arguments: Arguments,
        workingDirectory: FilePath?,
    ) async throws -> ShellOutput
    func run(
        _ executable: Executable,
        arguments: Arguments,
    ) async throws -> ShellOutput
}

@MainActor
struct RuntimeEnvironment: Environment {
    
    let region: String?
    let log: Logger
    init(region: String? = nil, log: Logger) {
        self.region = region
        self.log = log
    }
    
    // Utilities classes
    var fileHandler: FileHandlerProtocol { FileHandler(log: self.log) }

    // CLI related classes
    var display: DisplayProtocol = Display()
    var readLine: ReadLineProtocol = ReadLine()

    // progress bar
    var progressBar: CLIProgressBarProtocol = CLIProgressBar()

    // Secrets - will be overwritten by CLI when using AWS Secrets Manager
    private var _secrets: SecretsHandlerProtocol? = nil
    var secrets: SecretsHandlerProtocol? {
        get {
            _secrets ?? SecretsStorageFile(log: log)
        }
        set {
            _secrets = newValue
         }
    }

    // Commands
    var authenticator: AppleAuthenticatorProtocol {
        AppleAuthenticator(env: self, log: self.log)
    }
    var downloader: AppleDownloaderProtocol {
        AppleDownloader(env: self, log: self.log)
    }

    // Network
    var urlSessionData: URLSessionProtocol = URLSession.shared
    func urlSessionDownload(
        dstFilePath: URL? = nil,
        totalFileSize: Int? = nil,
        startTime: Date? = nil
    ) -> URLSessionProtocol {
        URLSession(
            configuration: .default,
            delegate: DownloadDelegate(
                env: self,
                dstFilePath: dstFilePath,
                totalFileSize: totalFileSize,
                startTime: startTime,
                semaphore: DispatchSemaphore(value: 0),
                log: self.log
            ),
            delegateQueue: nil
        )
    }

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
        try await Subprocess.run(
            executable,
            arguments: arguments,
            environment: .inherit,
            workingDirectory: workingDirectory,
            platformOptions: PlatformOptions(),
            input: .none,
            output: .string(limit: 1024, encoding: UTF8.self),
            error: .string(limit: 1024, encoding: UTF8.self))
    }
}
