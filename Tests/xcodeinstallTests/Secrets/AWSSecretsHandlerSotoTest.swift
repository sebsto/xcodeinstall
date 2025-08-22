//
//  AWSSecretsHandlerSotoTest.swift
//  xcodeinstallTests
//
//  Created by Stormacq, Sebastien on 16/09/2022.
//

import Foundation
import SotoCore
import SotoSecretsManager
import XCTest

@testable import xcodeinstall

final class AWSSecretsHandlerSotoTest: XCTestCase {

    var secretHandler: AWSSecretsHandlerSoto?

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

            secretHandler =
                try AWSSecretsHandlerSoto.forRegion(region, awsClient: awsClient, smClient: smClient)
                as? AWSSecretsHandlerSoto
            XCTAssertNotNil(secretHandler)

            if TestEnvironment.isUsingLocalstack {
                print("Connecting to Localstack")
            } else {
                print("Connecting to AWS")
            }

            // then
            // no error

        } catch AWSSecretsHandlerError.invalidRegion(let error) {
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
            let _ = try AWSSecretsHandlerSoto.forRegion(region)

            // then
            // no error

        } catch AWSSecretsHandlerError.invalidRegion(let error) {
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
            let _ = try AWSSecretsHandlerSoto.forRegion(region)

            // then
            // error
            XCTAssert(false, "an error must be thrown")

        } catch AWSSecretsHandlerError.invalidRegion(let error) {
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
        } catch {
            if ProcessInfo.processInfo.environment["GITHUB_ACTIONS"] == nil {
                XCTAssert(false, "unexpected error : \(error)")
            }
        }

    }
#endif
}

