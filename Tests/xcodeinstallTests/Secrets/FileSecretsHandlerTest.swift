//
//  FileSecretHandlerTest.swift
//  xcodeinstallTests
//
//  Created by Stormacq, Sebastien on 05/08/2022.
//

import XCTest

@testable import xcodeinstall

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

class FileSecretsHandlerTest: AsyncTestCase, SecretsHandlerTestProtocol {

    var secretHandlerTest: SecretsHandlerTestBase<FileSecretsHandler>?

    override func asyncSetUpWithError() async throws {
        env = Environment.mock

        secretHandlerTest = SecretsHandlerTestBase()

        secretHandlerTest!.secrets = FileSecretsHandler()
        try await secretHandlerTest!.secrets!.clearSecrets()
    }

    override func asyncTearDownWithError() async throws {
        //        await self.secrets!.restoreSecrets()
    }

    func testMergeCookiesNoConflict() async throws {
        try await secretHandlerTest!.testMergeCookiesNoConflict()
    }

    func testMergeCookiesOneConflict() async throws {
        try await secretHandlerTest!.testMergeCookiesOneConflict()
    }

    func testLoadAndSaveSession() async throws {
        try await secretHandlerTest!.testLoadAndSaveSession()
    }

    func testLoadAndSaveCookies() async throws {
        try await secretHandlerTest!.testLoadAndSaveCookies()
    }

    func testLoadSessionNoExist() async {
        await secretHandlerTest!.testLoadSessionNoExist()
    }
}
