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
import XCTest

@testable import xcodeinstall
@MainActor
final class SecretsStorageAWSSotoTest: XCTestCase {

    var secretHandler: SecretsStorageAWSSoto?
    let log = Logger(label: "SecretsStorageAWSSotoTest")

    override func setUpWithError() throws {
        // given
        let region = "us-east-1"

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
            
//            try  MainActor.run {
//                self.secretHandler =
//                    try SecretsStorageAWSSoto.forRegion(region, awsClient: awsClient, smClient: smClient, log: self.log)
//                    as? SecretsStorageAWSSoto
//                XCTAssertNotNil(self.secretHandler)
//            }
            secretHandler =
                try SecretsStorageAWSSoto.forRegion(region, awsClient: awsClient, smClient: smClient, log: log)
                as? SecretsStorageAWSSoto
            XCTAssertNotNil(secretHandler)

            if TestEnvironment.isUsingLocalstack {
                print("Connecting to Localstack")
            } else {
                print("Connecting to AWS")
            }

            // then
            // no error

        } catch SecretsStorageAWSError.invalidRegion(let error) {
            XCTAssertEqual(region, error)
        } catch {
            XCTAssert(false, "unexpected error : \(error)")
        }

    }

    func testInitWithCorrectRegion() {

        // given
        let region = "us-east-1"

        // when
        do {
            let _ = try SecretsStorageAWSSoto.forRegion(region, log: log)

            // then
            // no error

        } catch SecretsStorageAWSError.invalidRegion(let error) {
            XCTAssert(false, "region rejected : \(error)")
        } catch {
            XCTAssert(false, "unexpected error : \(error)")
        }
    }

    func testInitWithIncorrectRegion() {

        // given
        let region = "invalid"

        // when
        do {
            let _ = try SecretsStorageAWSSoto.forRegion(region, log: log)

            // then
            // error
            XCTAssert(false, "an error must be thrown")

        } catch SecretsStorageAWSError.invalidRegion(let error) {
            XCTAssertEqual(region, error)
        } catch {
            XCTAssert(false, "unexpected error : \(error)")
        }
    }

    #if os(macOS)
    // [CI] on Linux fails because there is no AWS credentials provider configured
    func testCreateSecret() async {

        // given
        XCTAssertNotNil(secretHandler)
        let credentials = AppleCredentialsSecret(username: "username", password: "password")

        // when
        do {
            try await secretHandler!.updateSecret(secretId: .appleCredentials, newValue: credentials)
        } catch _ as CredentialProviderError {
            // ignore
            // it allows to run the test on machines not configured for AWS
        } catch {
            XCTFail("unexpected exception : \(error)")
        }

    }
    #endif
}
