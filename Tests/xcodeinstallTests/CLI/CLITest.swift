//
//  CLITest.swift
//  xcodeinstallTests
//
//  Created by Stormacq, Sebastien on 15/08/2022.
//

import XCTest
import ArgumentParser
import CLIlib
@testable import xcodeinstall


class CLITest: AsyncTestCase {
    
    var secretsHandler : SecretsHandlerProtocol!
    
    override func asyncSetUpWithError() async throws {
        
        env = Environment.mock
        
        self.secretsHandler = MockedSecretHandler()
        try await self.secretsHandler.clearSecrets()
        
    }

    override func asyncTearDownWithError() async throws {
//        secretsHandler.restoreSecrets()
    }
    
    func parse<A>(_ type: A.Type, _ arguments: [String]) throws -> A where A: AsyncParsableCommand {
        return try XCTUnwrap(MainCommand.parseAsRoot(arguments) as? A)
    }
        
    func assertDisplay(_ msg: String) {
        let actual = (env.display as! MockedDisplay).string
        XCTAssert(actual == "\(msg)\n")
    }
    func assertDisplayStartsWith(_ msg: String) {
        let actual = (env.display as! MockedDisplay).string
        XCTAssert(actual.starts(with: msg))
    }
}
