//
//  CLITest.swift
//  xcodeinstallTests
//
//  Created by Stormacq, Sebastien on 15/08/2022.
//

import XCTest
import ArgumentParser
@testable import xcodeinstall


class CLITest: AsyncTestCase {
    
    var log : Log!
    var secretsHandler : SecretsHandler!
    
    var mockedDisplay : DisplayProtocol!
    var mockedAuth : AppleAuthenticatorProtocol!
    var fileHandler : FileHandlerProtocol!
    
    override func asyncSetUpWithError() async throws {
        self.log = Log(logLevel: .debug)
        self.secretsHandler = FileSecretsHandler(logger: log.defaultLogger)

        try await self.secretsHandler.clearSecrets()
        self.mockedDisplay = MockedDisplay()
        
        self.fileHandler = MockedFileHandler()
    }

    override func asyncTearDownWithError() async throws {
//        secretsHandler.restoreSecrets()
    }
    
    func parse<A>(_ type: A.Type, _ arguments: [String]) throws -> A where A: AsyncParsableCommand {
        return try XCTUnwrap(MainCommand.parseAsRoot(arguments) as? A)
    }

    func xcodeinstall(input : ReadLineProtocol? = nil) -> XCodeInstall {

        let result : XCodeInstall?
        if let i = input {
            result = XCodeInstall(display: mockedDisplay,
                                  input: i,
                                  secretsManager: secretsHandler,
                                  logger: log.defaultLogger,
                                  fileHandler: self.fileHandler)
        } else {
            result = XCodeInstall(display: mockedDisplay,
                                  secretsManager: secretsHandler,
                                  logger: log.defaultLogger,
                                  fileHandler: self.fileHandler)
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
