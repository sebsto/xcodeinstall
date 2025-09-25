//
//  Environment.swift
//
//
//  Created by Stormacq, Sebastien on 22/11/2022.
//

import CLIlib
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

#if canImport(FoundationEssentials)
import FoundationEssentials
#else 
import Foundation
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
    var secrets: SecretsHandlerProtocol? { get }
    func setSecretsHandler(_ newValue: SecretsHandlerProtocol)
    var authenticator: AppleAuthenticatorProtocol { get }
    var downloader: AppleDownloaderProtocol { get }
    var urlSessionData: URLSessionProtocol { get }
    var downloadManager: DownloadManager { get }
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

final class RuntimeEnvironment: Environment {

    let region: String?
    let log: Logger

    init(region: String? = nil, log: Logger) {
        self.region = region
        self.log = log

        self._authenticator = AppleAuthenticator(log: log)
        self._downloader = AppleDownloader(log: log)
        self._fileHandler = FileHandler(log: log)
        self._secrets = SecretsStorageFile(log: log)

        self.urlSessionData = URLSession.shared
        self.downloadManager = DownloadManager(logger: self.log)
    }

    // CLI related classes
    var display: DisplayProtocol = Display()
    var readLine: ReadLineProtocol = ReadLine()

    // progress bar
    var progressBar: CLIProgressBarProtocol = CLIProgressBar()

    // Utilities classes
    private var _fileHandler: FileHandlerProtocol
    var fileHandler: FileHandlerProtocol { self._fileHandler }

    // Secrets - will be overwritten by CLI when using AWS Secrets Manager
    private var _secrets: SecretsHandlerProtocol? = nil
    var secrets: SecretsHandlerProtocol? {
        get { _secrets }
    }
    // provide an actor isolated setter
    func setSecretsHandler(_ newValue: SecretsHandlerProtocol) {
        self._secrets = newValue
    }
    
    // Commands
    private var _authenticator: AppleAuthenticatorProtocol
    var authenticator: AppleAuthenticatorProtocol {
        get {
            (self._authenticator as? AppleAuthenticator)?.environment = self
            return self._authenticator
        }
        set {
            self._authenticator = newValue
        }
    }
    private var _downloader: AppleDownloaderProtocol
    var downloader: AppleDownloaderProtocol {
        get {
            (self._downloader as? AppleDownloader)?.environment = self
            return self._downloader
        }
        set {
            self._downloader = newValue
        }
    }

    // Network
    let urlSessionData: URLSessionProtocol
    let downloadManager: DownloadManager

    func run(
        _ executable: Executable,
        arguments: Arguments,
    ) async throws -> ShellOutput {
        try await run(
            executable,
            arguments: arguments,
            workingDirectory: nil
        )
    }
    func run(
        _ executable: Executable,
        arguments: Arguments,
        workingDirectory: FilePath?,
    ) async throws -> ShellOutput {
        try await Subprocess.run(
            executable,
            arguments: arguments,
            environment: .inherit,
            workingDirectory: workingDirectory,
            platformOptions: PlatformOptions(),
            input: .none,
            output: .string(limit: 1024, encoding: UTF8.self),
            error: .string(limit: 1024, encoding: UTF8.self)
        )
    }
}
