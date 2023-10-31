//
//  CLIStoreSecrets.swift
//  xcodeinstall
//
//  Created by Stormacq, Sebastien on 01/09/2022.
//

import Foundation
import ArgumentParser
import CLIlib

extension MainCommand {

    struct StoreSecrets: AsyncParsableCommand {
        static var configuration =
        CommandConfiguration(commandName: "storesecrets",
                             abstract: "Store your Apple Developer Portal username and password in AWS Secrets Manager")

        @OptionGroup var globalOptions: GlobalOptions

        // repeat of CloudOption but this time mandatory
        @Option(name: [.customLong("secretmanager-region"), .short],
                help: "Instructs to use AWS Secrets Manager to store and read secrets in the given AWS Region")
        var secretManagerRegion: String

        func run() async throws {

            if globalOptions.verbose {
                log = Log.defaultLogger(logLevel: .debug, label: "xcodeinstall")
            } else {
                log = Log.defaultLogger(logLevel: .error, label: "xcodeinstall")
            }

            env.secrets = try AWSSecretsHandler(region: secretManagerRegion)

            let xci = XCodeInstall()
            _ = try await xci.storeSecrets()
        }
    }

}
