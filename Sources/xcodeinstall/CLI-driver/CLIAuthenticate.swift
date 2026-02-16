//
//  CLIAuthenticate.swift
//  xcodeinstall
//
//  Created by Stormacq, Sebastien on 23/07/2022.
//

import ArgumentParser
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

            let xci: XCodeInstall
            do {
                xci = try await MainCommand.XCodeInstaller(
                    with: deps,
                    for: cloudOption.secretManagerRegion,
                    profileName: cloudOption.profileName,
                    verbose: globalOptions.verbose,
                )
            } catch {
                await NooraDisplay().display(error.localizedDescription, terminator: "\n", style: .error())
                throw ExitCode.failure
            }

            do {
                try await xci.authenticate(with: AuthenticationMethod.withSRP(srp))
            } catch {
                try? await xci.deps.secrets?.shutdown()
                throw ExitCode.failure
            }

            // Gracefully shut down AWS client before process exits
            // to avoid RotatingCredentialProvider crash during deallocation
            try? await xci.deps.secrets?.shutdown()
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

            let xci: XCodeInstall
            do {
                xci = try await MainCommand.XCodeInstaller(
                    with: deps,
                    for: cloudOption.secretManagerRegion,
                    profileName: cloudOption.profileName,
                    verbose: globalOptions.verbose
                )
            } catch {
                await NooraDisplay().display(error.localizedDescription, terminator: "\n", style: .error())
                throw ExitCode.failure
            }

            do {
                try await xci.signout()
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
