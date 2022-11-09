//
//  CLIAuthenticate.swift
//  xcodeinstall
//
//  Created by Stormacq, Sebastien on 23/07/2022.
//

import Foundation
import ArgumentParser

import CLIlib

// download implementation
extension MainCommand {

    struct Download: AsyncParsableCommand {
        static var configuration = CommandConfiguration(abstract: "Download the specified version of Xcode")

        @OptionGroup var globalOptions: GlobalOptions
        @OptionGroup var downloadListOptions: DownloadListOptions

        @Option(name: .shortAndLong, help: "The exact package name to downloads. When omited, it asks interactively")
        var name: String?

        func run() async throws {
            
            if globalOptions.verbose {
                log = Log.verboseLogger(label: "xcodeinstall")
            } else {
                log = Log.defaultLogger(label: "xcodeinstall")
            }

            _ = try await XCodeInstall().download(fileName: name,
                                                  majorVersion: downloadListOptions.xCodeVersion,
                                                  sortMostRecentFirst: downloadListOptions.mostRecentFirst,
                                                  datePublished: downloadListOptions.datePublished)

        }
    }

}
