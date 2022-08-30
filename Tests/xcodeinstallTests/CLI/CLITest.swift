//
//  CLITest.swift
//  xcodeinstallTests
//
//  Created by Stormacq, Sebastien on 15/08/2022.
//

import XCTest
import ArgumentParser
@testable import xcodeinstall


class CLITest: XCTestCase {
    
    var log : Log!
    var secretsHandler : SecretsHandler!
    
    var mockedDisplay : DisplayProtocol!
    var mockedAuth : AppleAuthenticatorProtocol!
    
    override func setUpWithError() throws {
        self.log = Log(logLevel: .debug)
        self.secretsHandler = FileSecretsHandler(logger: log.defaultLogger)

        self.secretsHandler.clearSecrets(preserve: true)
        self.mockedDisplay = MockedDisplay()
    }

    override func tearDownWithError() throws {
        secretsHandler.restoreSecrets()
    }
    
    func parse<A>(_ type: A.Type, _ arguments: [String]) throws -> A where A: AsyncParsableCommand {
        return try XCTUnwrap(MainCommand.parseAsRoot(arguments) as? A)
    }

    func xcodeinstall(input : ReadLineProtocol? = nil) -> XCodeInstall {

        let result : XCodeInstall?
        if let i = input {
            result = XCodeInstall(display: mockedDisplay,input: i, secretsManager: secretsHandler, logger: log.defaultLogger)
        } else {
            result = XCodeInstall(display: mockedDisplay, secretsManager: secretsHandler, logger: log.defaultLogger)
        }
        return result!
    }
        
    func assertDisplay(_ msg: String) {
        let actual = (self.mockedDisplay as! MockedDisplay).string
        XCTAssert(actual == "\(msg)\n")
    }
    func assertDisplayStartsWith(_ msg: String) {
        let actual = (self.mockedDisplay as! MockedDisplay).string
        XCTAssert(actual.starts(with: msg))
    }
}
