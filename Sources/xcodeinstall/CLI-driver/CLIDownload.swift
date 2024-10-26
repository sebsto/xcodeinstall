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
        @OptionGroup var cloudOption: CloudOptions

        @Option(name: .shortAndLong, help: "The exact package name to downloads. When omited, it asks interactively")
        var name: String?

        func run() async throws {

            if globalOptions.verbose {
                log = Log.defaultLogger(logLevel: .debug, label: "xcodeinstall")
            } else {
                log = Log.defaultLogger(logLevel: .error, label: "xcodeinstall")
            }

            if let region = cloudOption.secretManagerRegion {
                env.secrets = try AWSSecretsHandler(region: region)
            }

            let xci = XCodeInstall()
            try await xci.download(fileName: name,
                                   force: downloadListOptions.force,
                                   xCodeOnly: downloadListOptions.onlyXcode,
                                   majorVersion: downloadListOptions.xCodeVersion,
                                   sortMostRecentFirst: downloadListOptions.mostRecentFirst,
                                   datePublished: downloadListOptions.datePublished)
        }
    }

}
