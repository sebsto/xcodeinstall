//
//  CLIInstall.swift
//  xcodeinstall
//
//  Created by Stormacq, Sebastien on 22/08/2022.
//

import ArgumentParser
import Logging

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

// Install implementation
extension MainCommand {

    struct Install: AsyncParsableCommand {

        nonisolated static let configuration =
            CommandConfiguration(abstract: "Install a specific XCode version or addon package")

        @OptionGroup var globalOptions: GlobalOptions

        @Option(
            name: .shortAndLong,
            help: "The exact package name to install. When omitted, it asks interactively"
        )
        var name: String?

        func run() async throws {
            try await run(with: nil)
        }

        func run(with deps: AppDependencies?) async throws {
            let xci = try await MainCommand.XCodeInstaller(
                with: deps,
                verbose: globalOptions.verbose
            )

            do {
                try await xci.install(file: name)
            } catch {
                throw ExitCode.failure
            }
        }
    }
}
