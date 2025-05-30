//
//  FileSecretHandlerTest.swift
//  xcodeinstallTests
//
//  Created by Stormacq, Sebastien on 05/08/2022.
//

import Testing

@testable import xcodeinstall

@Suite("FileSecretsHandlerTest", .serialized)
struct FileSecretsHandlerTest {

    var secretHandlerTest: SecretsHandlerTestsBase<FileSecretsHandler>?

    init() async throws {
        secretHandlerTest = SecretsHandlerTestsBase()

        secretHandlerTest!.secrets = await FileSecretsHandler()
        try await secretHandlerTest!.secrets!.clearSecrets()
    }

    @Test("Test Merge Cookies No Conflict")
    func testMergeCookiesNoConflict() async throws {
        try await secretHandlerTest!.testMergeCookiesNoConflict()
    }

    @Test("Test Merge Cookies One Conflict")
    func testMergeCookiesOneConflict() async throws {
        try await secretHandlerTest!.testMergeCookiesOneConflict()
    }

    @Test("Test Load and Save Session")
    func testLoadAndSaveSession() async throws {
        try await secretHandlerTest!.testLoadAndSaveSession()
    }

    @Test("Test Load and Save Cookies")
    func testLoadAndSaveCookies() async throws {
        try await secretHandlerTest!.testLoadAndSaveCookies()
    }

    @Test("Test Load Session No Exist")
    func testLoadSessionNoExist() async {
        await secretHandlerTest!.testLoadSessionNoExist()
    }
}
