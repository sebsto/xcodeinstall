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

// download implementation
extension MainCommand {

    struct Download: AsyncParsableCommand {
        nonisolated static let configuration = CommandConfiguration(
            abstract: "Download the specified version of Xcode"
        )

        @OptionGroup var globalOptions: GlobalOptions
        @OptionGroup var downloadListOptions: DownloadListOptions
        @OptionGroup var cloudOption: CloudOptions

        @Option(
            name: .shortAndLong,
            help: "The exact package name to downloads. When omited, it asks interactively"
        )
        var name: String?

        func run() async throws {
            try await run(with: RuntimeEnvironment())
        }

        func run(with env: Environment) async throws {

            let xci = try await MainCommand.XCodeInstaller(
                with: env,
                for: cloudOption.secretManagerRegion,
                verbose: globalOptions.verbose
            )

            try await xci.download(
                fileName: name,
                force: downloadListOptions.force,
                xCodeOnly: downloadListOptions.onlyXcode,
                majorVersion: downloadListOptions.xCodeVersion,
                sortMostRecentFirst: downloadListOptions.mostRecentFirst,
                datePublished: downloadListOptions.datePublished
            )
        }
    }

}
