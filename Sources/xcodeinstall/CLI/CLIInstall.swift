//
//  CLIInstall.swift
//  xcodeinstall
//
//  Created by Stormacq, Sebastien on 22/08/2022.
//

import Foundation
import ArgumentParser

// Install implementation
extension MainCommand {

    struct Install: AsyncParsableCommand {

        static var configuration =
        CommandConfiguration(abstract: "Install a specific XCode version or addon package")

        @OptionGroup var globalOptions: GlobalOptions

        @Option(name: .shortAndLong, help: "The exact package name to install. When omited, it asks interactively")
        var name: String?

        func run() async throws {
            let main = try XCodeInstallBuilder()
                            .withVerbosity(verbose: globalOptions.verbose)
                            .withInstaller()
                            .build()
            _ = try await main.install(file: name)
        }
    }
}
