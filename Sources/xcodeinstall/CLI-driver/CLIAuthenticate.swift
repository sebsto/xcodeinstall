//
//  CLIAuthenticate.swift
//  xcodeinstall
//
//  Created by Stormacq, Sebastien on 23/07/2022.
//

import ArgumentParser
import CLIlib
import Foundation

extension MainCommand {

    struct Authenticate: AsyncParsableCommand {
        static var configuration =
            CommandConfiguration(abstract: "Authenticate yourself against Apple Developer Portal")

        @OptionGroup var globalOptions: GlobalOptions
        @OptionGroup var cloudOption: CloudOptions

        @Option(name: .long, help: "Use SRP authentication")
        var srp = true

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
            try await xci.authenticate(with: AuthenticationMethod.withSRP(srp))
        }
    }

    struct Signout: AsyncParsableCommand {
        static var configuration = CommandConfiguration(abstract: "Signout from Apple Developer Portal")

        @OptionGroup var globalOptions: GlobalOptions
        @OptionGroup var cloudOption: CloudOptions

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
            try await xci.signout()
        }
    }

}
