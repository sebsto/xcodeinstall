//
//  CLIDownloadTest.swift
//  xcodeinstallTests
//
//  Created by Stormacq, Sebastien on 22/08/2022.
//

import ArgumentParser
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
        assertDisplay("Unknown file name : xxx.xip")

        // verify shutdown was called on the secrets handler
        #expect((deps.secrets as? MockedSecretsHandler)?.shutdownCalled == true)
    }

}
