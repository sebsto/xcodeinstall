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

// MARK: - Focused dependency protocols

/// File system operations (download list cache, file existence checks, move)
protocol FileHandling: Sendable {
    var fileHandler: FileHandlerProtocol { get }
}

/// CLI user interaction (display messages, read input, progress bars)
protocol CLIInterface: Sendable {
    var display: DisplayProtocol { get }
    var readLine: ReadLineProtocol { get }
    var progressBar: CLIProgressBarProtocol { get }
}

/// Secrets storage (cookies, sessions, credentials)
protocol SecretStoring: Sendable {
    var secrets: SecretsHandlerProtocol? { get }
}

/// Shell command execution
protocol ShellExecuting: Sendable {
    func run(
        _ executable: Executable,
        arguments: Arguments,
        workingDirectory: FilePath?
    ) async throws -> ShellOutput
    func run(
        _ executable: Executable,
        arguments: Arguments
    ) async throws -> ShellOutput
}

/// Network operations (authentication, downloads)
protocol Networking: Sendable {
    var authenticator: AppleAuthenticatorProtocol { get }
    var downloader: AppleDownloaderProtocol { get }
    var urlSessionData: URLSessionProtocol { get }
}

// MARK: - Production shell executor

struct SystemShell: ShellExecuting, Sendable {
    func run(
        _ executable: Executable,
        arguments: Arguments,
        workingDirectory: FilePath?
    ) async throws -> ShellOutput {
        try await Subprocess.run(
            executable,
            arguments: arguments,
            environment: .inherit,
            workingDirectory: workingDirectory,
            platformOptions: PlatformOptions(),
            input: .none,
            output: .string(limit: 2048, encoding: UTF8.self),
            error: .string(limit: 2048, encoding: UTF8.self)
        )
    }

    func run(
        _ executable: Executable,
        arguments: Arguments
    ) async throws -> ShellOutput {
        try await run(executable, arguments: arguments, workingDirectory: nil)
    }
}

// MARK: - AppDependencies

struct AppDependencies: Sendable {
    let fileHandler: FileHandlerProtocol
    var display: DisplayProtocol
    var readLine: ReadLineProtocol
    var progressBar: CLIProgressBarProtocol
    var secrets: SecretsHandlerProtocol?
    var authenticator: AppleAuthenticatorProtocol
    var downloader: AppleDownloaderProtocol
    let urlSessionData: URLSessionProtocol
    let shell: any ShellExecuting
    let log: Logger
}
