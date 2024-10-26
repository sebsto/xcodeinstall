//
//  CLIInstall.swift
//  xcodeinstall
//
//  Created by Stormacq, Sebastien on 22/08/2022.
//

import ArgumentParser
import CLIlib
import Foundation

// Install implementation
extension MainCommand {

    struct Install: AsyncParsableCommand {

        static var configuration =
            CommandConfiguration(abstract: "Install a specific XCode version or addon package")

        @OptionGroup var globalOptions: GlobalOptions

        @Option(
            name: .shortAndLong,
            help: "The exact package name to install. When omited, it asks interactively"
        )
        var name: String?

        func run() async throws {

            if globalOptions.verbose {
                log = Log.defaultLogger(logLevel: .debug, label: "xcodeinstall")
            } else {
                log = Log.defaultLogger(logLevel: .error, label: "xcodeinstall")
            }

            let xci = XCodeInstall()
            _ = try await xci.install(file: name)
        }
    }
}
