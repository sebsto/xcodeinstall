//
//  XcodeInstall.swift
//  xcodeinstall
//
//  Created by Stormacq, Sebastien on 16/08/2022.
//

import CLIlib
import Logging

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

final class XCodeInstall {

    let log: Logger
    var deps: AppDependencies

    public init(log: Logger, deps: AppDependencies) {
        self.log = log
        self.deps = deps
    }

    // display a message to the user
    // avoid having to replicate the \n torough the code
    func display(_ msg: String, terminator: String = "\n") {
        self.deps.display.display(msg, terminator: terminator)
    }

}
