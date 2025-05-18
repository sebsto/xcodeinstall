//
//  CLIInstall.swift
//  xcodeinstall
//
//  Created by Stormacq, Sebastien on 22/08/2022.
//

import ArgumentParser
import CLIlib
import Foundation
import Logging

// Install implementation
@MainActor
extension MainCommand {

    struct Install: AsyncParsableCommand {

        nonisolated static let configuration =
            CommandConfiguration(abstract: "Install a specific XCode version or addon package")

        @OptionGroup var globalOptions: GlobalOptions

        @Option(
            name: .shortAndLong,
            help: "The exact package name to install. When omited, it asks interactively"
        )
        var name: String?

        func run() async throws {

            let xci = try await MainCommand.XCodeInstaller(verbose: globalOptions.verbose)

            _ = try await xci.install(file: name)
        }
    }
}
