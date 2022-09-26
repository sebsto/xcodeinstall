//
//  XcodeInstall.swift
//  xcodeinstall
//
//  Created by Stormacq, Sebastien on 16/08/2022.
//

import Foundation
import CLIlib
import Logging

struct XCodeInstall {

    // shared functionalities : read input from stdin

    // the display implementation to display messages to users, allows to inject a mock for testing
    var display: DisplayProtocol = Display()

    // the input function to collect user entry, allows to inject a mocked implementation for testing
    var input: ReadLineProtocol = ReadLine()

    // display a message to the user
    func display(_ msg: String, terminator: String = "\n") {
        display.display(msg, terminator: terminator)
    }

    // specialised classes to implement functionalities
    // allows to inject other implementations for testing
    // declared here because extension can not hold variables
    var authenticator: AppleAuthenticatorProtocol?
    var downloader: AppleDownloaderProtocol?
    var installer: InstallerProtocol?

    var secretsManager: SecretsHandler
    var logger: Logger
    var fileHandler: FileHandlerProtocol
}

enum XCodeInstallError: Error {
    case configurationError(msg: String)
}
