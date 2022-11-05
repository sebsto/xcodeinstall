//
//  CLIAuthenticate.swift
//  xcodeinstall
//
//  Created by Stormacq, Sebastien on 23/07/2022.
//

import Foundation
import ArgumentParser

import CLIlib

// list implementation
extension MainCommand {

    struct DownloadListOptions: ParsableArguments {

        static var configuration =
        CommandConfiguration(abstract: "Common options for list and download commands", shouldDisplay: false)

        @Option(name: [.customLong("xcode-version"), .short], help: "Filter on provided Xcode version number")
        var xCodeVersion: String = "14"

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
            
            if globalOptions.verbose {
                log = Log.verboseLogger(label: "xcodeinstall")
            } else {
                log = Log.defaultLogger(label: "xcodeinstall")
            }

            _ = try await XCodeInstall().list(majorVersion: downloadListOptions.xCodeVersion,
                                              sortMostRecentFirst: downloadListOptions.mostRecentFirst,
                                              datePublished: downloadListOptions.datePublished)
        }
    }
}
