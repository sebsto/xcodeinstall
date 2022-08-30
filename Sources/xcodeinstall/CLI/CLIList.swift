//
//  CLIAuthenticate.swift
//  xcodeinstall
//
//  Created by Stormacq, Sebastien on 23/07/2022.
//

import Foundation
import ArgumentParser

// download implementation
extension MainCommand {

    struct DownloadListOptions: ParsableArguments {

        static var configuration =
        CommandConfiguration(abstract: "Common options for list and download commands", shouldDisplay: false)

        @Flag(name: .shortAndLong,
              help: "Force to download the list from Apple Developer Portal, even if we have it in the cache")
        var force: Bool = false

        @Flag(name: .shortAndLong, help: "Filter on Xcode package only")
        var onlyXcode: Bool = false

        @Option(name: [.customLong("xcode-version"), .short], help: "Filter on provided Xcode version number")
        var xCodeVersion: String = "13"

        @Flag(name: .shortAndLong, help: "Sort by most recent releases first")
        var mostRecentFirst: Bool = false

        @Flag(name: .shortAndLong, help: "Show publication date")
        var datePublished: Bool = false

    }

    struct List: AsyncParsableCommand {

        static var configuration =
        CommandConfiguration(abstract: "List available versions of Xcode and development tools")

        @OptionGroup var globalOptions: GlobalOptions
        @OptionGroup var downloadListOptions: DownloadListOptions

        func run() async throws {
            let main = XCodeInstallBuilder()
                            .with(verbosityLevel: globalOptions.verbose ? .debug : .warning)
                            .withDownloader()
                            .build()
            _ = try await main.list(force: downloadListOptions.force,
                                            xCodeOnly: downloadListOptions.onlyXcode,
                                            majorVersion: downloadListOptions.xCodeVersion,
                                            sortMostRecentFirst: downloadListOptions.mostRecentFirst,
                                            datePublished: downloadListOptions.datePublished)
        }
    }
}
