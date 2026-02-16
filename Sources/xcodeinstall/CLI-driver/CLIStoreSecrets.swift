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
                abstract: "Store your Apple Developer Portal username and password in AWS Secrets Manager"
            )

        @OptionGroup var globalOptions: GlobalOptions

        // repeat of CloudOption but this time mandatory
        @Option(
            name: [.customLong("secretmanager-region"), .short],
            help: "Instructs to use AWS Secrets Manager to store and read secrets in the given AWS Region"
        )
        var secretManagerRegion: String

        @Option(
            name: [.customLong("profile"), .customShort("p")],
            help: "The AWS profile name to use for authentication (from ~/.aws/credentials and ~/.aws/config)"
        )
        var profileName: String?

        func run() async throws {
            try await run(with: nil)
        }

        func run(with deps: AppDependencies?) async throws {
            let xci: XCodeInstall
            do {
                xci = try await MainCommand.XCodeInstaller(
                    with: deps,
                    for: secretManagerRegion,
                    profileName: profileName,
                    verbose: globalOptions.verbose
                )
            } catch {
                await NooraDisplay().display(error.localizedDescription, terminator: "\n", style: .error())
                throw ExitCode.failure
            }

            do {
                _ = try await xci.storeSecrets()
            } catch {
                try? await xci.deps.secrets?.shutdown()
                throw ExitCode.failure
            }

            // Gracefully shut down AWS client before process exits
            // to avoid RotatingCredentialProvider crash during deallocation
            try? await xci.deps.secrets?.shutdown()
        }
    }

}
