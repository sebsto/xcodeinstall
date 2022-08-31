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

    struct Download: AsyncParsableCommand {
        static var configuration = CommandConfiguration(abstract: "Download the specified version of Xcode")

        @OptionGroup var globalOptions: GlobalOptions
        @OptionGroup var downloadListOptions: DownloadListOptions

        @Option(name: .shortAndLong, help: "The exact package name to downloads. When omited, it asks interactively")
        var name: String?

        func run() async throws {
            let main = XCodeInstallBuilder()
                            .with(verbosityLevel: globalOptions.verbose ? .debug : .warning)
                            .withDownloader()
                            .build()
            try await main.download(fileName: name,
                                    force: downloadListOptions.force,
                                    xCodeOnly: downloadListOptions.onlyXcode,
                                    majorVersion: downloadListOptions.xCodeVersion,
                                    sortMostRecentFirst: downloadListOptions.mostRecentFirst,
                                    datePublished: downloadListOptions.datePublished)
        }
    }

}
