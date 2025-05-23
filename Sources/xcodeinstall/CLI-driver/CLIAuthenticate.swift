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

extension MainCommand {

    struct Authenticate: AsyncParsableCommand {
        nonisolated static let configuration =
            CommandConfiguration(abstract: "Authenticate yourself against Apple Developer Portal")

        @OptionGroup var globalOptions: GlobalOptions
        @OptionGroup var cloudOption: CloudOptions

        @Option(name: .long, help: "Use SRP authentication")
        var srp = true

        func run() async throws {
            try await run(with: RuntimeEnvironment(region: cloudOption.secretManagerRegion))
        }

        func run(with env: Environment) async throws {

            let xci = try await MainCommand.XCodeInstaller(
                with: env,
                for: cloudOption.secretManagerRegion,
                verbose: globalOptions.verbose
            )

            try await xci.authenticate(with: AuthenticationMethod.withSRP(srp))
        }
    }

    struct Signout: AsyncParsableCommand {
        nonisolated static let configuration = CommandConfiguration(abstract: "Signout from Apple Developer Portal")

        @OptionGroup var globalOptions: GlobalOptions
        @OptionGroup var cloudOption: CloudOptions

        func run() async throws {
            try await run(with: RuntimeEnvironment(region: cloudOption.secretManagerRegion))
        }

        func run(with env: Environment) async throws {

            let xci = try await MainCommand.XCodeInstaller(
                with: env,
                for: cloudOption.secretManagerRegion,
                verbose: globalOptions.verbose
            )
            try await xci.signout()
        }
    }

}
