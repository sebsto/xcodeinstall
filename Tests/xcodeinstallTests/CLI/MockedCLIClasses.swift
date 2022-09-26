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
class MockedReadLine : ReadLineProtocol {
    
    var input : [String]
    
    init(_ input : [String]) {
        self.input = input.reversed()
    }
    
    func readLine(prompt: String, silent: Bool = false) -> String? {
        return input.popLast()
    }
}

enum MockError: Error {
    case invalidMockData
}

class MockedInstaller: InstallerProtocol {
    
    var nextError : Error?

    func install(file: String, progress: ProgressUpdateProtocol) async throws {

        if let nextError {
            throw nextError
        }
        
    }
}
