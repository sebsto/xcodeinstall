//
//  XcodeInstall.swift
//  xcodeinstall
//
//  Created by Stormacq, Sebastien on 16/08/2022.
//

import CLIlib
import Foundation
import Logging

@MainActor
struct XCodeInstall {

    let log: Logger
    let env: Environment

    public init(log: Logger = Log.defaultLogger(), env: Environment) {
        self.log = log
        self.env = env
    }

    // display a message to the user
    // avoid having to replicate the \n torough the code
    func display(_ msg: String, terminator: String = "\n") {
        self.env.display.display(msg, terminator: terminator)
    }

}
