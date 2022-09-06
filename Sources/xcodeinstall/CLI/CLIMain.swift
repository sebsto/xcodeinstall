//
//  CLI.swift
//  xcodeinstall
//
//  Created by Stormacq, Sebastien on 18/07/2022.
//

import Foundation
import ArgumentParser

enum CLIError: Error {
    case invalidInput
}

@main
struct MainCommand: AsyncParsableCommand {

    // arguments that are global to all commands
    struct GlobalOptions: ParsableArguments {

        @Flag(name: .shortAndLong, help: "Produce verbose output for debugging")
        var verbose = false
    }

    // arguments for Authenticate, Signout, List, and Download
    struct CloudOptions: ParsableArguments {

        @Option(name: [.customLong("secretmanager-region"), .short],
                help: "Instructs to use AWS Secrets Manager to store and read secrets in the given AWS Region")
        var secretManagerRegion: String?
    }

    @OptionGroup var globalOptions: GlobalOptions

    // Customize the command's help and subcommands by implementing the
    // `configuration` property.
    static var configuration = CommandConfiguration(
        commandName: "xcodeinstall",

        // Optional abstracts and discussions are used for help output.
        abstract: "A utility to download and install Xcode",

        // Commands can define a version for automatic '--version' support.
        version: "0.3",

        // Pass an array to `subcommands` to set up a nested tree of subcommands.
        // With language support for type-level introspection, this could be
        // provided by automatically finding nested `ParsableCommand` types.
        subcommands: [Authenticate.self, Signout.self, List.self,
                      Download.self, Install.self, StoreSecrets.self]

        // A default subcommand, when provided, is automatically selected if a
        // subcommand is not given on the command line.
        // defaultSubcommand: List.self)
    )

}
