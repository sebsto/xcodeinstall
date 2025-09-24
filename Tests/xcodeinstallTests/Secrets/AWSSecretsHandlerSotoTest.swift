//
//  SecretsStorageAWSSotoTest.swift
//  xcodeinstallTests
//
//  Created by Stormacq, Sebastien on 16/09/2022.
//

import Foundation
import Logging
import SotoCore
import SotoSecretsManager
import Testing

@testable import xcodeinstall
@Suite("Secrets Storage AWS Soto")
struct SecretsStorageAWSSotoTest {

    var secretHandler: SecretsStorageAWSSoto?
    let log = Logger(label: "SecretsStorageAWSSotoTest")

    init() throws {
        // given
        let region = "eu-central-1"

        // when
        do {
            let awsClient = AWSClient(
                credentialProvider: TestEnvironment.credentialProvider,
                httpClientProvider: .createNew
            )
            let smClient = SecretsManager(
                client: awsClient,
                endpoint: TestEnvironment.getEndPoint()
            )
            
            secretHandler =
                try SecretsStorageAWSSoto.forRegion(region, awsClient: awsClient, smClient: smClient, log: log)
                as? SecretsStorageAWSSoto
            #expect(secretHandler != nil)

            if TestEnvironment.isUsingLocalstack {
                print("Connecting to Localstack")
            } else {
                print("Connecting to AWS")
            }

            // then
            // no error

        } catch SecretsStorageAWSError.invalidRegion(let error) {
            #expect(region == error)
        } catch {
            Issue.record("unexpected error : \(error)")
        }

    }

    @Test("Test Init With Correct Region")
    func testInitWithCorrectRegion() {

        // given
        let region = "eu-central-1"

        // when
        let _ = #expect(throws: Never.self) {
            let _ = try SecretsStorageAWSSoto.forRegion(region, log: log)
        }
    }

    @Test("Test Init With Incorrect Region")
    func testInitWithIncorrectRegion() {

        // given
        let region = "invalid"

        // when
        let error = #expect(throws: SecretsStorageAWSError.self) {
            let _ = try SecretsStorageAWSSoto.forRegion(region, log: log)
        }
        if case let .invalidRegion(errorRegion) = error {
            #expect(region == errorRegion)
        } else {
            Issue.record("Expected invalidRegion error")
        }
    }

    #if os(macOS)
    // [CI] on Linux fails because there is no AWS credentials provider configured
    @Test("Test Create Secret")
    func testCreateSecret() async {

        // given
        #expect(secretHandler != nil)
        let credentials = AppleCredentialsSecret(username: "username", password: "password")

        // when
        do {
            try await secretHandler!.updateSecret(secretId: .appleCredentials, newValue: credentials)
        } catch _ as CredentialProviderError {
            // ignore
            // it allows to run the test on machines not configured for AWS
        } catch {
            Issue.record("unexpected exception : \(error)")
        }

    }
    #endif
}
