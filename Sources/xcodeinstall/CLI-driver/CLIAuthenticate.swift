//
//  CLIAuthenticate.swift
//  xcodeinstall
//
//  Created by Stormacq, Sebastien on 23/07/2022.
//

import ArgumentParser
import CLIlib
import Logging

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

extension MainCommand {

    struct Authenticate: AsyncParsableCommand {
        nonisolated static let configuration =
            CommandConfiguration(abstract: "Authenticate yourself against Apple Developer Portal")

        @OptionGroup var globalOptions: GlobalOptions
        @OptionGroup var cloudOption: CloudOptions

        @Option(name: .long, help: "Use SRP authentication")
        var srp = true

        func run() async throws {
            try await run(with: nil)
        }

        func run(with deps: AppDependencies?) async throws {

            let xci = try await MainCommand.XCodeInstaller(
                with: deps,
                for: cloudOption.secretManagerRegion,
                verbose: globalOptions.verbose,
            )

            try await xci.authenticate(with: AuthenticationMethod.withSRP(srp))
        }
    }

    struct Signout: AsyncParsableCommand {
        nonisolated static let configuration = CommandConfiguration(abstract: "Signout from Apple Developer Portal")

        @OptionGroup var globalOptions: GlobalOptions
        @OptionGroup var cloudOption: CloudOptions

        func run() async throws {
            try await run(with: nil)
        }

        func run(with deps: AppDependencies?) async throws {

            let xci = try await MainCommand.XCodeInstaller(
                with: deps,
                for: cloudOption.secretManagerRegion,
                verbose: globalOptions.verbose
            )
            try await xci.signout()
        }
    }

}
