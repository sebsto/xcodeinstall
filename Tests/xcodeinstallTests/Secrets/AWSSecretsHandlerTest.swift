//
//  FileSecretHandlerTest.swift
//  xcodeinstallTests
//
//  Created by Stormacq, Sebastien on 05/08/2022.
//

import Logging
import Testing

@testable import xcodeinstall

struct SecretsStorageAWSTest {

    var secretHandlerTest: SecretsHandlerTestsBase<SecretsStorageAWS>? = nil
    let log = Logger(label: "SecretsStorageAWSTest")

    @available(macOS 15.0, *)
    init() async throws {

        secretHandlerTest = SecretsHandlerTestsBase()

        let AWS_REGION = "us-east-1"

        let mockedSDK = try MockedSecretsStorageAWSSDK.forRegion(AWS_REGION, log: log)
        secretHandlerTest!.secrets = try SecretsStorageAWS(sdk: mockedSDK, log: log)
        try await secretHandlerTest!.secrets!.clearSecrets()
    }

    @available(macOS 15.0, *)
    @Test("Test Merge Cookies No Conflict")
    func testMergeCookiesNoConflict() async throws {
        try await secretHandlerTest!.testMergeCookiesNoConflict()
    }

    @available(macOS 15.0, *)
    @Test("Test Merge Cookies One Conflict")
    func testMergeCookiesOneConflict() async throws {
        try await secretHandlerTest!.testMergeCookiesOneConflict()
    }

    @available(macOS 15.0, *)
    @Test("Test Load and Save Session")
    func testLoadAndSaveSession() async throws {
        try await secretHandlerTest!.testLoadAndSaveSession()
    }

    @available(macOS 15.0, *)
    @Test("Test Load and Save Cookies")
    func testLoadAndSaveCookies() async throws {
        try await secretHandlerTest!.testLoadAndSaveCookies()
    }

    @available(macOS 15.0, *)
    @Test("Test Load Session No Exist")
    func testLoadSessionNoExist() async {
        await secretHandlerTest!.testLoadSessionNoExist()
    }

}
