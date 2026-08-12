//
//  CliListTest.swift
//  xcodeinstallTests
//
//  Created by Stormacq, Sebastien on 22/08/2022.
//

import ArgumentParser
import Foundation
import Testing

@testable import xcodeinstall

extension CLITests {

    @Test("Test List Command")
    func testList() async throws {

        // given
        let list = try parse(
            MainCommand.List.self,
            [
                "list",
                "--verbose",
                "--only-xcode",
                "--xcode-version",
                "14",
                "--most-recent-first",
                "--date-published",
            ]
        )

        let deps = env.toDeps(log: log)

        // when

        await #expect(throws: Never.self) { try await list.run(with: deps) }

        // test parsing of commandline arguments
        #expect(list.globalOptions.verbose)
        #expect(list.downloadListOptions.onlyXcode)
        #expect(list.downloadListOptions.xCodeVersion == "14")
        #expect(list.downloadListOptions.mostRecentFirst)
        #expect(list.downloadListOptions.datePublished)

        // mocked list succeeded
        assertDisplay("16 items")

        // verify shutdown was called on the secrets handler
        #expect((deps.secrets as? MockedSecretsHandler)?.shutdownCalled == true)
    }

    // MARK: - List Error Path Tests
    // errors are rendered by the CLI layer, so these run the command end to end

    /// Runs `xcodeinstall list` against a downloader that fails with `error`.
    private func runListExpectingFailure(
        _ error: Error,
        in env: MockedEnvironment
    ) async throws {
        env.downloader.nextListError = error
        let deps = env.toDeps(log: log)
        let list = try parse(MainCommand.List.self, ["list", "--only-xcode", "--xcode-version", "14"])

        await #expect(throws: ExitCode.self) { try await list.run(with: deps) }
    }

    @Test("Test List Authentication Required")
    func testListAuthenticationRequired() async throws {
        // given
        let env = MockedEnvironment()

        // when
        try await runListExpectingFailure(DownloadError.authenticationRequired, in: env)

        // then
        assertDisplayContains(env: env, "Session expired")
    }

    @Test("Test List Account Need Upgrade")
    func testListAccountNeedUpgrade() async throws {
        // given
        let env = MockedEnvironment()

        // when
        try await runListExpectingFailure(
            DownloadError.accountNeedUpgrade(errorCode: 2170, errorMessage: "upgrade needed"),
            in: env
        )

        // then
        assertDisplayContains(env: env, "upgrade needed")
        assertDisplayContains(env: env, "2170")
    }

    @Test("Test List Need To Accept Terms And Condition")
    func testListNeedToAcceptTermsAndCondition() async throws {
        // given
        let env = MockedEnvironment()

        // when
        try await runListExpectingFailure(DownloadError.needToAcceptTermsAndCondition, in: env)

        // then
        assertDisplayContains(env: env, "you need first to accept")
    }

    @Test("Test List Unknown Error")
    func testListUnknownError() async throws {
        // given
        let env = MockedEnvironment()

        // when
        try await runListExpectingFailure(
            DownloadError.unknownError(errorCode: 9999, errorMessage: "Something broke"),
            in: env
        )

        // then
        assertDisplayContains(env: env, "Unhandled download error")
    }

    @Test("Test List Secrets Storage AWS Error")
    func testListSecretsStorageAWSError() async throws {
        // given
        let env = MockedEnvironment()

        // when
        try await runListExpectingFailure(SecretsStorageAWSError.invalidRegion(region: "bad-region"), in: env)

        // then
        assertDisplayContains(env: env, "AWS Error")
    }

    @Test("Test List Unexpected Error")
    func testListUnexpectedError() async throws {
        // given
        let env = MockedEnvironment()

        // when
        try await runListExpectingFailure(MockError.genericTestError, in: env)

        // then
        assertDisplayContains(env: env, "Unexpected error")
    }

    @Test("Test List propagates the error to its caller")
    func testListPropagatesError() async throws {
        // given
        let env = MockedEnvironment()
        env.downloader.nextListError = DownloadError.authenticationRequired
        let deps = env.toDeps(log: log)
        let xci = XCodeInstall(log: log, deps: deps)

        // when — the business layer throws without displaying anything
        await #expect(throws: DownloadError.authenticationRequired) {
            _ = try await xci.list(
                force: false,
                xCodeOnly: true,
                majorVersion: "14",
                sortMostRecentFirst: false,
                datePublished: false
            )
        }

        // then
        let messages = (env.display as! MockedDisplay).allMessages
        #expect(!messages.contains(where: { $0.contains("Session expired") }))
    }

    @Test("Test List From Network Forced")
    func testListFromNetworkForced() async throws {
        // given
        let env = MockedEnvironment()
        env.downloader.nextListSource = .network
        let deps = env.toDeps(log: log)
        let xci = XCodeInstall(log: log, deps: deps)

        // when
        await #expect(throws: Never.self) {
            _ = try await xci.list(
                force: true,
                xCodeOnly: true,
                majorVersion: "14",
                sortMostRecentFirst: false,
                datePublished: false
            )
        }

        // then
        assertDisplayContains(env: env, "Forced download from Apple Developer Portal")
    }

    @Test("Test List From Network Not Forced")
    func testListFromNetworkNotForced() async throws {
        // given
        let env = MockedEnvironment()
        env.downloader.nextListSource = .network
        let deps = env.toDeps(log: log)
        let xci = XCodeInstall(log: log, deps: deps)

        // when
        await #expect(throws: Never.self) {
            _ = try await xci.list(
                force: false,
                xCodeOnly: true,
                majorVersion: "14",
                sortMostRecentFirst: false,
                datePublished: false
            )
        }

        // then
        assertDisplayContains(env: env, "No cache found, downloaded from Apple Developer Portal")
    }
}
