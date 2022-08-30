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

        func run() async throws {
            let main = XCodeInstallBuilder()
                            .with(verbosityLevel: globalOptions.verbose ? .debug : .warning)
                            .withDownloader()
                            .build()
            try await main.download(force: downloadListOptions.force,
                                            xCodeOnly: downloadListOptions.onlyXcode,
                                            majorVersion: downloadListOptions.xCodeVersion,
                                            sortMostRecentFirst: downloadListOptions.mostRecentFirst,
                                            datePublished: downloadListOptions.datePublished)
        }
    }

}
