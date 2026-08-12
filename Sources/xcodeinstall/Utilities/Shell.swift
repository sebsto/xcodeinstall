//
//  ShellOutput.swift
//  xcodeinstall
//
//  Created by Stormacq, Sebastien on 16/05/2025.
//

import Subprocess

#if canImport(System)
import System
#else
import SystemPackage
#endif

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

// MARK: - Production shell executor

struct SystemShell: ShellExecuting, Sendable {

    /// Maximum number of bytes collected from stdout and stderr.
    /// `Subprocess.run` throws a `SubprocessError` when a command emits more than this.
    private static let outputLimit = 2048

    func run(
        _ executable: Executable,
        arguments: Arguments,
        workingDirectory: FilePath?
    ) async throws -> ShellOutput {
        let result = try await Subprocess.run(
            executable,
            arguments: arguments,
            environment: .inherit,
            workingDirectory: workingDirectory,
            platformOptions: PlatformOptions(),
            input: .none,
            output: .string(limit: Self.outputLimit, encoding: UTF8.self),
            error: .string(limit: Self.outputLimit, encoding: UTF8.self)
        )
        return ShellOutput(
            terminationStatus: result.terminationStatus,
            standardOutput: result.standardOutput,
            standardError: result.standardError
        )
    }

    func run(
        _ executable: Executable,
        arguments: Arguments
    ) async throws -> ShellOutput {
        try await run(executable, arguments: arguments, workingDirectory: nil)
    }
}

// MARK: - Shell command result

/// The outcome of a shell command.
///
/// This is deliberately a type we own rather than a typealias for `Subprocess`'
/// generic result type. `swift-subprocess` reshaped that type twice before 1.0
/// (`CollectedResult` -> `ExecutionRecord` -> `ExecutionResult`, with a new
/// `ClosureResult` generic parameter), and each change rippled through every
/// call site and test mock. Mapping once, in `SystemShell`, keeps that churn
/// contained to this file.
nonisolated struct ShellOutput: Sendable, CustomStringConvertible {
    let terminationStatus: TerminationStatus
    let standardOutput: String
    let standardError: String

    var description: String {
        """
        ShellOutput(
            terminationStatus: \(self.terminationStatus),
            standardOutput: \(self.standardOutput),
            standardError: \(self.standardError)
        )
        """
    }
}

extension Executable {
    public static func path(_ path: String) -> Self {
        Executable.path(FilePath(path))
    }
}
