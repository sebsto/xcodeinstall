//
//  CLIStoreSecrets.swift
//  xcodeinstallTests
//
//  Created by Stormacq, Sebastien on 15/09/2022.
//

import Testing

@testable import xcodeinstall

@MainActor
extension CLITests {

    @Test("Test Store Secrets")
    func testStoreSecrets() async throws {

        // given
        let mockedRL = MockedReadLine(["username", "password"])
        let env = MockedEnvironment(readLine: mockedRL)
        // use the real AWS Secrets Handler, but with a mocked SDK
        //FIXME - the mock should be in the ENV
        let _ = try AWSSecretsHandler(env: env, region: "us-east-1")

        let storeSecrets = try parse(
            MainCommand.StoreSecrets.self,
            [
                "storesecrets",
                "-s", "us-east-1",
                "--verbose",
            ]
        )

        // when
        await #expect(throws: Never.self) { try await storeSecrets.run(with: env) }

        // test parsing of commandline arguments
        #expect(storeSecrets.globalOptions.verbose)

        // did we call setRegion on the SDK class ?
        #expect((env.awsSDK as? MockedAWSSecretsHandlerSDK)?.regionSet() ?? false)
    }

    func testPromptForCredentials() {

        // given
        let mockedRL = MockedReadLine(["username", "password"])
        let env = MockedEnvironment(readLine: mockedRL)
        let xci = XCodeInstall(env: env)

        // when
        do {
            let result = try xci.promptForCredentials()

            // then
            #expect(result.count == 2)
            #expect(result[0] == "username")
            #expect(result[1] == "password")

        } catch {
            // then
            Issue.record("unexpected exception : \(error)")
        }

    }

}
