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

typealias ShellOutput = CollectedResult<StringOutput<Unicode.UTF8>, StringOutput<Unicode.UTF8>>

extension Executable {
    public static func path(_ path: String) -> Self {
        Executable.path(FilePath(path))
    }
}
