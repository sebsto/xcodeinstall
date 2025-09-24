//
//  File.swift
//  xcodeinstallTests
//
//  Created by Stormacq, Sebastien on 15/08/2022.
//

import CLIlib
import Foundation

@testable import xcodeinstall

//
// CLI Testing
//

// mocked display (use class because string is mutating)
final class MockedDisplay: DisplayProtocol {
    var string: String = ""

    func display(_ msg: String, terminator: String) {
        self.string = msg + terminator
    }
}

// mocked read line
final class MockedReadLine: ReadLineProtocol {

    var input: [String] = []

    init(_ input: [String]) {
        self.input = input.reversed()
    }

    func readLine(prompt: String, silent: Bool = false) -> String? {
        guard input.count > 0 else {
            fatalError("mocked not correctly initialized")
        }
        return input.popLast()
    }
}

enum MockError: Error {
    case invalidMockData
}
