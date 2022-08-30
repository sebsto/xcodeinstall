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

class MockedProgressBar: ProgressUpdateProtocol {
    
    var isComplete = false
    var isClear    = false
    var step  = 0
    var total = 0
    var text  = ""
    
    func update(step: Int, total: Int, text: String) {
        self.step  = step
        self.total = total
        self.text  = text
    }
    
    func complete(success: Bool) {
        isComplete = success
    }
    
    func clear() {
        isClear = true
    }
    
    
}

class MockedInstaller: InstallerProtocol {
    
    var nextError : Error?

    func install(file: String, progress: ProgressUpdateProtocol) async throws {

        if let error = nextError {
            throw error
        }
        
    }
}
