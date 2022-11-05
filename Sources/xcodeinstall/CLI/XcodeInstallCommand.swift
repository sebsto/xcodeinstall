//
//  XcodeInstall.swift
//  xcodeinstall
//
//  Created by Stormacq, Sebastien on 16/08/2022.
//

import Foundation
import CLIlib

struct XCodeInstall {

    // shared functionalities : read input from stdin

    // the display implementation to display messages to users, allows to inject a mock for testing
    let display: DisplayProtocol = env.display

    // the input function to collect user entry, allows to inject a mocked implementation for testing
    let input: ReadLineProtocol = env.readLine

    // display a message to the user
    func display(_ msg: String, terminator: String = "\n") {
        display.display(msg, terminator: terminator)
    }
}
