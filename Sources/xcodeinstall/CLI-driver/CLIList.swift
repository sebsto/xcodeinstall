//
//  CLIAuthenticate.swift
//  xcodeinstall
//
//  Created by Stormacq, Sebastien on 23/07/2022.
//

import ArgumentParser
import CLIlib
import Foundation
import Logging

// list implementation
extension MainCommand {

    struct DownloadListOptions: ParsableArguments {

        nonisolated static let configuration =
            CommandConfiguration(
                abstract: "Common options for list and download commands",
                shouldDisplay: false
            )

        @Flag(
            name: .shortAndLong,
            help:
                "Force to download the list from Apple Developer Portal, even if we have it in the cache"
        )
        var force: Bool = false

        @Flag(name: .shortAndLong, help: "Filter on Xcode package only")
        var onlyXcode: Bool = false

        @Option(
            name: [.customLong("xcode-version"), .short],
            help: "Filter on provided Xcode version number"
        )
        var xCodeVersion: String = "15"

        @Flag(name: .shortAndLong, help: "Sort by most recent releases first")
        var mostRecentFirst: Bool = false

        @Flag(name: .shortAndLong, help: "Show publication date")
        var datePublished: Bool = false

    }

    @MainActor
    struct List: AsyncParsableCommand {

        nonisolated static let configuration =
            CommandConfiguration(abstract: "List available versions of Xcode and development tools")

        @OptionGroup var globalOptions: GlobalOptions
        @OptionGroup var downloadListOptions: DownloadListOptions
        @OptionGroup var cloudOption: CloudOptions

        func run() async throws {
            try await run(with: RuntimeEnvironment(region: cloudOption.secretManagerRegion))
        }

        func run(with env: Environment) async throws {

            let xci = try await MainCommand.XCodeInstaller(
                with: env,
                for: cloudOption.secretManagerRegion,
                verbose: globalOptions.verbose
            )

            _ = try await xci.list(
                force: downloadListOptions.force,
                xCodeOnly: downloadListOptions.onlyXcode,
                majorVersion: downloadListOptions.xCodeVersion,
                sortMostRecentFirst: downloadListOptions.mostRecentFirst,
                datePublished: downloadListOptions.datePublished
            )
        }
    }
}
