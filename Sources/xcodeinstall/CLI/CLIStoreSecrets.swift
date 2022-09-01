//
//  CLIStoreSecrets.swift
//  xcodeinstall
//
//  Created by Stormacq, Sebastien on 01/09/2022.
//

import Foundation
import ArgumentParser

extension MainCommand {

    struct StoreSecrets: AsyncParsableCommand {
        static var configuration =
        CommandConfiguration(commandName: "storesecrets",
                             abstract: "Store your Apple Developer Portal username and password in AWS Secrets Manager")

        @OptionGroup var globalOptions: GlobalOptions
        @OptionGroup var cloudOption: CloudOptions

        func run() async throws {
        }
    }

}
