//
//  CLIAuthenticate.swift
//  xcodeinstall
//
//  Created by Stormacq, Sebastien on 23/07/2022.
//

import Foundation
import ArgumentParser

extension MainCommand {

    struct Authenticate: AsyncParsableCommand {
        static var configuration =
               CommandConfiguration(abstract: "Authenticate yourself against Apple Developer Portal")

        @OptionGroup var globalOptions: GlobalOptions
        @OptionGroup var cloudOption: CloudOptions

        func run() async throws {
            var xcib = XCodeInstallBuilder()
                            .with(verbosityLevel: globalOptions.verbose ? .debug : .warning)
                            .withAuthenticator()

            if let region = cloudOption.secretManagerRegion {
                xcib = xcib.withAWSSecretsManager(region: region)
            }

            try await xcib.build().authenticate()
        }
    }

    struct Signout: AsyncParsableCommand {
        static var configuration = CommandConfiguration(abstract: "Signout from Apple Developer Portal")

        @OptionGroup var globalOptions: GlobalOptions
        @OptionGroup var cloudOption: CloudOptions

        func run() async throws {
            let main = try XCodeInstallBuilder()
                            .with(verbosityLevel: globalOptions.verbose ? .debug : .warning)
                            .withAuthenticator()
                            .build()

            try await main.signout()
        }
    }

}
