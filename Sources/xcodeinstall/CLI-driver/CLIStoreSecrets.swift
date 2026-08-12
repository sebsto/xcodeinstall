//
//  CLIStoreSecrets.swift
//  xcodeinstall
//
//  Created by Stormacq, Sebastien on 01/09/2022.
//

import ArgumentParser
import Logging

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

extension MainCommand {

    struct StoreSecrets: AsyncParsableCommand {
        nonisolated static let configuration =
            CommandConfiguration(
                commandName: "storesecrets",
                abstract: "Store your Apple Developer Portal username and password in AWS Parameter Store"
            )

        @OptionGroup var globalOptions: GlobalOptions

        // repeat of CloudOption but this time mandatory
        @Option(
            name: [.customLong("secret-region"), .short],
            help: "Instructs to store and read secrets on AWS in the given AWS Region"
        )
        var secretRegion: String

        @Option(
            name: [.customLong("profile"), .customShort("p")],
            help: "The AWS profile name to use for authentication (from ~/.aws/credentials and ~/.aws/config)"
        )
        var profileName: String?

        func run() async throws {
            try await run(with: nil)
        }

        func run(with deps: AppDependencies?) async throws {
            let xci = try await MainCommand.makeXCodeInstall(
                with: deps,
                for: secretRegion,
                profileName: profileName,
                verbose: globalOptions.verbose
            )

            try await MainCommand.run(on: xci) {
                try await xci.storeSecrets()
            }
        }
    }

}
