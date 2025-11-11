//
//  CLIStoreSecrets.swift
//  xcodeinstallTests
//
//  Created by Stormacq, Sebastien on 15/09/2022.
//

import Foundation
import SotoCore
import Testing

@testable import xcodeinstall

extension CLITests {

    // on CI Linux, there is no AWS credentials configured
    // this test throws "No credential provider found" of type CredentialProviderError
    #if os(macOS)
    // fails on CI CD, disable temporarily
    @available(macOS 15.0, *)
    @Test("Test Store Secrets", .enabled(if: ProcessInfo.processInfo.environment["GITHUB_ACTIONS"] == nil))
    func testStoreSecrets() async throws {

        // given
        let mockedRL = MockedReadLine(["username", "password"])
        let env: Environment = MockedEnvironment(readLine: mockedRL)
        // use the real AWS Secrets Handler, but with a mocked SDK
        let mockedSDK = try MockedSecretsStorageAWSSDK.forRegion("us-east-1", log: log)
        let secretsHandler = try SecretsStorageAWS(sdk: mockedSDK, log: log)
        env.setSecretsHandler(secretsHandler)

        let storeSecrets = try parse(
            MainCommand.StoreSecrets.self,
            [
                "storesecrets",
                "-s", "eu-central-1",
                "--verbose",
            ]
        )

        // when
        do {
            try await storeSecrets.run(with: env)
        } catch _ as CredentialProviderError {
            // ignore
            // it allows to run the test on machines not configured for AWS
        } catch {
            Issue.record("unexpected exception : \(error)")
        }

        // test parsing of commandline arguments
        #expect(storeSecrets.globalOptions.verbose)

        //FIXME : can't do that here - because the mocked secret handler just has a copy of the env,
        //it can not modify the env we have here

        // did we call setRegion on the SDK class ?
        #expect((secretsHandler.awsSDK as? MockedSecretsStorageAWSSDK)?.regionSet() ?? false)
    }
    #endif

    func testPromptForCredentials() {

        // given
        let mockedRL = MockedReadLine(["username", "password"])
        let env = MockedEnvironment(readLine: mockedRL)
        let xci = XCodeInstall(log: log, env: env)

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
