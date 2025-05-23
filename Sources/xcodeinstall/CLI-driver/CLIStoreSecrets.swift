//
//  CLIStoreSecrets.swift
//  xcodeinstall
//
//  Created by Stormacq, Sebastien on 01/09/2022.
//

import ArgumentParser
import CLIlib
import Foundation
import Logging

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

        func run() async throws {
            // this command works with secrets stored in the cloud
//            var env = await RuntimeEnvironment(region: secretManagerRegion)
//            env.secrets = try  await AWSSecretsHandler(env: env, region: secretManagerRegion)
//            try await run(with: env)
            
            //TODO: I think we don't need to create a secret handler here, XCodeInstaller will create one
            try await run(with: RuntimeEnvironment(region: secretManagerRegion))
        }

        func run(with env: Environment) async throws {

            let xci = try await MainCommand.XCodeInstaller(
                with: env,
                for: secretManagerRegion,
                verbose: globalOptions.verbose
            )

            _ = try await xci.storeSecrets()
        }
    }

}
