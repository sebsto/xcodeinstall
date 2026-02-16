//
//  File.swift
//  xcodeinstallTests
//
//  Created by Stormacq, Sebastien on 15/08/2022.
//

import Foundation

@testable import xcodeinstall

//
// CLI Testing
//

// mocked display (use class because string is mutating)
final class MockedDisplay: DisplayProtocol {
    var string: String = ""
    var allMessages: [String] = []

    func display(_ msg: String, terminator: String, style: DisplayStyle) {
        self.string = msg + terminator
        self.allMessages.append(msg)
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

// mocked read line that always returns nil
final class NilMockedReadLine: ReadLineProtocol {
    func readLine(prompt: String, silent: Bool = false) -> String? {
        nil
    }
}

enum MockError: Error {
    case invalidMockData
    case genericTestError
}
