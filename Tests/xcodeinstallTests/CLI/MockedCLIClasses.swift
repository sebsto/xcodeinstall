//
//  File.swift
//  xcodeinstallTests
//
//  Created by Stormacq, Sebastien on 15/08/2022.
//

import Foundation
import CLIlib
@testable import xcodeinstall

//
// CLI Testing
//

// mocked display (use class because string is mutating)
class MockedDisplay: DisplayProtocol {
    var string : String = ""
    
    func display(_ msg: String, terminator: String) {
        self.string = msg + terminator
    }
}

// mocked read line
class MockedReadLine: ReadLineProtocol {

    var input: [String]?

    public init() {
    }

    public init(_ input: [String]) {
        self.input = input.reversed()
    }

    public func readLine(prompt: String, silent: Bool = false) -> String? {
        guard var input else {
            return nil
        }
        return input.popLast()
    }
}

