//
//  XcodeInstall.swift
//  xcodeinstall
//
//  Created by Stormacq, Sebastien on 16/08/2022.
//

import CLIlib
import Foundation

struct XCodeInstall {

    // display a message to the user
    // avoid having to replicate the \n torough the code
    func display(_ msg: String, terminator: String = "\n") {
        env.display.display(msg, terminator: terminator)
    }

}
