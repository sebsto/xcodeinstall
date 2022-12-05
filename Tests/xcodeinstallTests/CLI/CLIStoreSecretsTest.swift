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
        env.readLine = MockedReadLine(["username", "password"])

        // use the real AWS Secrets Handler, but with a mocked SDK
        var secretsHandler = try AWSSecretsHandler(region: "us-east-1")
        secretsHandler.awsSDK = try MockedAWSSecretsHandlerSDK()
        env.secrets = secretsHandler

        let inst = try parse(MainCommand.StoreSecrets.self, [
                            "storesecrets",
                            "-s", "us-east-1",
                            "--verbose"
        ])
        
        // when
        do {
            try await inst.run()
        } catch {
            // then
            XCTAssert(false, "unexpected exception : \(error)")
        }

        // test parsing of commandline arguments
        XCTAssert(inst.globalOptions.verbose)
    }
    
    func testPromptForCredentials() {
        
        // given
        env.readLine = MockedReadLine(["username", "password"])
        let xci = XCodeInstall()

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
