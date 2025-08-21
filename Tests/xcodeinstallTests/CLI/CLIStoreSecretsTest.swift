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

// on CI Linux, there is no AWS credentials configured
// this test throws "No credential provider found" of type CredentialProviderError
#if os(macOS)
    // fails on CI CD, disable temporarily
    @Test("Test Store Secrets", .enabled(if: ProcessInfo.processInfo.environment["GITHUB_ACTIONS"] == nil))
    func testStoreSecrets() async throws {

        // given
        let mockedRL = MockedReadLine(["username", "password"])
        var env: Environment = MockedEnvironment(readLine: mockedRL)
        // use the real AWS Secrets Handler, but with a mocked SDK
        let mockedSDK = try MockedAWSSecretsHandlerSDK.forRegion("us-east-1")
        let secretsHandler = try AWSSecretsHandler(env: env, sdk: mockedSDK)
        env.secrets = secretsHandler

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

        //FIXME : can't do that here - because the mocked secret handler just has a copy of the env,
        //it can not modify the env we have here 
        
        // did we call setRegion on the SDK class ?
        #expect((secretsHandler.awsSDK as? MockedAWSSecretsHandlerSDK)?.regionSet() ?? false)
    }
#endif    

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
