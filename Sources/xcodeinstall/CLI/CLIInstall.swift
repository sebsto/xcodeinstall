//
//  CLIInstall.swift
//  xcodeinstall
//
//  Created by Stormacq, Sebastien on 22/08/2022.
//

import Foundation
import ArgumentParser

import CLIlib

// Install implementation
extension MainCommand {

    struct Install: AsyncParsableCommand {

        static var configuration =
        CommandConfiguration(abstract: "Install a specific XCode version or addon package")

        @OptionGroup var globalOptions: GlobalOptions

        @Option(name: .shortAndLong, help: "The exact package name to install. When omited, it asks interactively")
        var name: String?

        func run() async throws {

            if globalOptions.verbose {
                log = Log.verboseLogger(label: "xcodeinstall")
            } else {
                log = Log.defaultLogger(label: "xcodeinstall")
            }

            _ = try await XCodeInstall().install(file: name)
        }
    }
}
