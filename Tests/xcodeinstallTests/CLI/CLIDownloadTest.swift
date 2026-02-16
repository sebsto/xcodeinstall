//
//  CLIDownloadTest.swift
//  xcodeinstallTests
//
//  Created by Stormacq, Sebastien on 22/08/2022.
//

import ArgumentParser
import Foundation
import Testing

@testable import xcodeinstall

extension CLITests {

    @Test("Test Download")
    func testDownload() async throws {

        // given

        let mockedRL = MockedReadLine(["0"])
        let mockedFH = MockedFileHandler()
        mockedFH.nextFileCorrect = true
        let mockedPB = MockedProgressBar()
        let env = MockedEnvironment(fileHandler: mockedFH, readLine: mockedRL, progressBar: mockedPB)

        let download = try parse(
            MainCommand.Download.self,
            [
                "download",
                "--verbose",
                "--force",
                "--only-xcode",
                "--xcode-version",
                "14",
                "--most-recent-first",
                "--date-published",
            ]
        )
        // test parsing of commandline arguments
        #expect(download.globalOptions.verbose)
        #expect(download.downloadListOptions.force)
        #expect(download.downloadListOptions.onlyXcode)
        #expect(download.downloadListOptions.xCodeVersion == "14")
        #expect(download.downloadListOptions.mostRecentFirst)
        #expect(download.downloadListOptions.datePublished)

        let deps = env.toDeps(log: log)

        // when
        await #expect(throws: Never.self) {
            let xci = XCodeInstall(log: log, deps: deps)
            try await xci.download(
                fileName: nil,
                force: false,
                xCodeOnly: true,
                majorVersion: "14",
                sortMostRecentFirst: true,
                datePublished: true
            )
        }

        // verify if progressbar define() was called
        if let progress = env.progressBar as? MockedProgressBar {
            #expect(progress.defineCalled())
        } else {
            Issue.record("Error in test implementation, the env.progressBar must be a MockedProgressBar")
        }

        // mocked list succeeded
        assertDisplay(env: env, "file downloaded")

    }

    @Test("Test Download with correct file name")
    func testDownloadWithCorrectFileName() async throws {

        // given
        (env.fileHandler as! MockedFileHandler).nextFileCorrect = true
        let fileName = "Xcode 14.xip"

        let download = try parse(
            MainCommand.Download.self,
            [
                "download",
                "--name",
                fileName,
            ]
        )

        let deps = env.toDeps(log: log)

        // when
        await #expect(throws: Never.self) {
            try await download.run(with: deps)
        }

        // test parsing of commandline arguments
        #expect(download.name == fileName)
        #expect(!download.globalOptions.verbose)
        #expect(!download.downloadListOptions.force)
        #expect(!download.downloadListOptions.onlyXcode)
        #expect(!download.downloadListOptions.mostRecentFirst)
        #expect(!download.downloadListOptions.datePublished)

        // mocked list succeeded
        assertDisplay("\(fileName) downloaded")

        // verify shutdown was called on the secrets handler
        #expect((deps.secrets as? MockedSecretsHandler)?.shutdownCalled == true)
    }

    @Test("Test Download with incorrect file name")
    func testDownloadWithIncorrectFileName() async throws {

        // given
        (env.fileHandler as! MockedFileHandler).nextFileCorrect = false
        let fileName = "xxx.xip"

        let download = try parse(
            MainCommand.Download.self,
            [
                "download",
                "--name",
                fileName,
            ]
        )

        let deps = env.toDeps(log: log)

        // when
        await #expect(throws: ExitCode.self) {
            try await download.run(with: deps)
        }

        // test parsing of commandline arguments
        #expect(download.name == fileName)
        #expect(!download.globalOptions.verbose)
        #expect(!download.downloadListOptions.force)
        #expect(!download.downloadListOptions.onlyXcode)
        #expect(!download.downloadListOptions.mostRecentFirst)
        #expect(!download.downloadListOptions.datePublished)

        // mocked list succeeded
        assertDisplay("Unknown file name : xxx.xip")

        // verify shutdown was called on the secrets handler
        #expect((deps.secrets as? MockedSecretsHandler)?.shutdownCalled == true)
    }

    // MARK: - Download Error Path Tests

    @Test("Test Download authentication required error")
    func testDownloadAuthenticationRequired() async throws {

        // given
        (env.fileHandler as! MockedFileHandler).nextFileCorrect = true
        let fileName = "Xcode 14.xip"
        env.downloader.nextDownloadError = DownloadError.authenticationRequired

        let deps = env.toDeps(log: log)

        // when
        await #expect(throws: DownloadError.self) {
            let xci = XCodeInstall(log: log, deps: deps)
            try await xci.download(
                fileName: fileName,
                force: false,
                xCodeOnly: false,
                majorVersion: "14",
                sortMostRecentFirst: false,
                datePublished: false
            )
        }

        // then
        assertDisplayStartsWith("Session expired")
    }

    @Test("Test Download user cancelled")
    func testDownloadUserCancelled() async throws {

        // given
        // Empty string input triggers CLIError.userCancelled in askUser()
        let mockedRL = MockedReadLine([""])
        let mockedFH = MockedFileHandler()
        mockedFH.nextFileCorrect = true
        let env = MockedEnvironment(fileHandler: mockedFH, readLine: mockedRL)

        let deps = env.toDeps(log: log)

        // when - userCancelled is caught silently with return, no error thrown
        await #expect(throws: Never.self) {
            let xci = XCodeInstall(log: log, deps: deps)
            try await xci.download(
                fileName: nil,
                force: false,
                xCodeOnly: true,
                majorVersion: "14",
                sortMostRecentFirst: false,
                datePublished: false
            )
        }
    }

    @Test("Test Download invalid input")
    func testDownloadInvalidInput() async throws {

        // given
        // Non-numeric input triggers CLIError.invalidInput in askUser()
        let mockedRL = MockedReadLine(["abc"])
        let mockedFH = MockedFileHandler()
        mockedFH.nextFileCorrect = true
        let env = MockedEnvironment(fileHandler: mockedFH, readLine: mockedRL)

        let deps = env.toDeps(log: log)

        // when
        await #expect(throws: CLIError.self) {
            let xci = XCodeInstall(log: log, deps: deps)
            try await xci.download(
                fileName: nil,
                force: false,
                xCodeOnly: true,
                majorVersion: "14",
                sortMostRecentFirst: false,
                datePublished: false
            )
        }

        // then
        assertDisplay(env: env, "Invalid input")
    }

    @Test("Test Download AWS Secrets Storage error")
    func testDownloadSecretsStorageAWSError() async throws {

        // given
        env.downloader.nextListError = SecretsStorageAWSError.invalidRegion(region: "bad-region")

        let deps = env.toDeps(log: log)

        // when
        await #expect(throws: SecretsStorageAWSError.self) {
            let xci = XCodeInstall(log: log, deps: deps)
            try await xci.download(
                fileName: "Xcode 14.xip",
                force: false,
                xCodeOnly: false,
                majorVersion: "14",
                sortMostRecentFirst: false,
                datePublished: false
            )
        }

        // then
        assertDisplayStartsWith("AWS Error")
    }

    @Test("Test Download generic error")
    func testDownloadGenericError() async throws {

        // given
        env.downloader.nextListError = NSError(domain: "test", code: 42, userInfo: nil)

        let deps = env.toDeps(log: log)

        // when
        await #expect(throws: Error.self) {
            let xci = XCodeInstall(log: log, deps: deps)
            try await xci.download(
                fileName: "Xcode 14.xip",
                force: false,
                xCodeOnly: false,
                majorVersion: "14",
                sortMostRecentFirst: false,
                datePublished: false
            )
        }

        // then
        assertDisplayStartsWith("Unexpected error")
    }

    @Test("Test Download ask file out of bounds")
    func testAskFileOutOfBounds() async throws {

        // given
        // Input "999" is way beyond the parsed list size
        let mockedRL = MockedReadLine(["999"])
        let mockedFH = MockedFileHandler()
        mockedFH.nextFileCorrect = true
        let env = MockedEnvironment(fileHandler: mockedFH, readLine: mockedRL)

        let deps = env.toDeps(log: log)

        // when
        await #expect(throws: CLIError.self) {
            let xci = XCodeInstall(log: log, deps: deps)
            try await xci.download(
                fileName: nil,
                force: false,
                xCodeOnly: true,
                majorVersion: "14",
                sortMostRecentFirst: false,
                datePublished: false
            )
        }

        // then
        assertDisplay(env: env, "Invalid input")
    }

    @Test("Test Download incomplete file")
    func testDownloadIncompleteFile() async throws {

        // given
        // File size check will fail, simulating an incomplete download
        let mockedRL = MockedReadLine(["0"])
        let mockedFH = MockedFileHandler()
        mockedFH.nextFileCorrect = false
        let mockedPB = MockedProgressBar()
        let env = MockedEnvironment(fileHandler: mockedFH, readLine: mockedRL, progressBar: mockedPB)

        let deps = env.toDeps(log: log)

        // when - download succeeds but file size check fails
        await #expect(throws: Never.self) {
            let xci = XCodeInstall(log: log, deps: deps)
            try await xci.download(
                fileName: nil,
                force: false,
                xCodeOnly: true,
                majorVersion: "14",
                sortMostRecentFirst: true,
                datePublished: false
            )
        }

        // then - should display incomplete/corrupted warning
        assertDisplayStartsWith(env: env, "Downloaded file has incorrect size")
    }

}
