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

        func run() async throws {
            let main = XCodeInstallBuilder()
                            .with(verbosityLevel: globalOptions.verbose ? .debug : .warning)
                            .withAuthenticator()
                            .build()

            try await main.authenticate()
        }
    }

    struct Signout: AsyncParsableCommand {
        static var configuration = CommandConfiguration(abstract: "Signout from Apple Developer Portal")

        @OptionGroup var globalOptions: GlobalOptions

        func run() async throws {
            let main = XCodeInstallBuilder()
                            .with(verbosityLevel: globalOptions.verbose ? .debug : .warning)
                            .withAuthenticator()
                            .build()

            try await main.signout()
        }
    }

}
