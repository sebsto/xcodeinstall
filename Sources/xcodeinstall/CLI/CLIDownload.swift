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
        @OptionGroup var cloudOption: CloudOptions

        @Option(name: .shortAndLong, help: "The exact package name to downloads. When omited, it asks interactively")
        var name: String?

        func run() async throws {
            var xcib = XCodeInstallBuilder()
                            .withDownloader()

            if let region = cloudOption.secretManagerRegion {
                xcib = xcib.withAWSSecretsManager(region: region)
            }

            try await xcib.build().download(fileName: name,
                                            force: downloadListOptions.force,
                                            xCodeOnly: downloadListOptions.onlyXcode,
                                            majorVersion: downloadListOptions.xCodeVersion,
                                            sortMostRecentFirst: downloadListOptions.mostRecentFirst,
                                            datePublished: downloadListOptions.datePublished)
        }
    }

}
