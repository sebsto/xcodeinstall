//
//  CLIStoreSecrets.swift
//  xcodeinstallTests
//
//  Created by Stormacq, Sebastien on 15/09/2022.
//

import XCTest
@testable import xcodeinstall

class CLIStoreSecretsTest: CLITest {
    
    func testStoreSecrets() async throws {
        
        // given
        let mockedReadline = MockedReadLine(["username", "password"])
        var xci = xcodeinstall(input: mockedReadline)
        xci.fileHandler = MockedFileHandler()
        
        // use the real AWS Secrets Handler, but with a mocked SDK
        var secretHandler = try AWSSecretsHandler(region: "us-east-1", logger: log.defaultLogger)
        secretHandler.awsSDK = try MockedAWSSecretsHandlerSDK()
        xci.secretsManager = secretHandler
        
        let inst = try parse(MainCommand.StoreSecrets.self, [
                            "storesecrets",
                            "-s", "us-east-1",
                            "--verbose"
        ])
        
        // when
        do {
            try await xci.storeSecrets()
        } catch {
            // then
            XCTAssert(false, "unexpected exception : \(error)")
        }

        // test parsing of commandline arguments
        XCTAssert(inst.globalOptions.verbose)
    }
    
    func testPromptForCredentials() {
        
        // given
        let mockedReadline = MockedReadLine(["username", "password"])
        var xci = xcodeinstall(input: mockedReadline)
        xci.fileHandler = MockedFileHandler()

        
        // when
        do {
            let result = try xci.promptForCredentials()
            
            // then
            XCTAssertTrue(result.count == 2)
            XCTAssertEqual(result[0], "username")
            XCTAssertEqual(result[1], "password")

        } catch {
            // then
            XCTAssert(false, "unexpected exception : \(error)")
        }

    }

}
