//
//  CLIInstallTest.swift
//  xcodeinstallTests
//
//  Created by Stormacq, Sebastien on 22/08/2022.
//

import ArgumentParser
import Testing

@testable import xcodeinstall

extension CLITests {

    @Test("Test Install Command")
    func testInstall() async throws {

        // given
        let env: MockedEnvironment = MockedEnvironment(progressBar: MockedProgressBar())
        let deps = env.toDeps(log: log)
        let inst = try parse(
            MainCommand.Install.self,
            [
                "install",
                "--verbose",
                "--name",
                "test.xip",
            ]
        )

        // when
        await #expect(throws: ExitCode.self) { try await inst.run(with: deps) }

        // test parsing of commandline arguments
        #expect(inst.globalOptions.verbose)
        #expect(inst.name == "test.xip")

        // verify if progressbar define() was called
        if let progress = env.progressBar as? MockedProgressBar {
            #expect(progress.defineCalled())
        } else {
            Issue.record("Error in test implementation, the env.progressBar must be a MockedProgressBar")
        }
    }

    @Test("Test Install Command with no name")
    func testPromptForFile() {

        // given
        let env: MockedEnvironment = MockedEnvironment(readLine: MockedReadLine(["0"]))
        let deps = env.toDeps(log: log)
        let xci = XCodeInstall(log: log, deps: deps)

        // when
        do {
            let result = try xci.promptForFile()

            // then
            #expect(result.lastPathComponent.hasSuffix("name.dmg"))

        } catch {
            // then
            Issue.record("unexpected exception : \(error)")
        }

    }

    // MARK: - Install Error Path Tests

    @Test("Test Install with no downloaded file list")
    func testInstallNoDownloadedList() async throws {

        // given
        let env: MockedEnvironment = MockedEnvironment(
            readLine: MockedReadLine(["0"]),
            progressBar: MockedProgressBar()
        )
        (env.fileHandler as! MockedFileHandler).nextDownloadedFilesError = FileHandlerError.noDownloadedList
        let deps = env.toDeps(log: log)
        let xci = XCodeInstall(log: log, deps: deps)

        // when (file: nil triggers promptForFile which calls downloadedFiles())
        await #expect(throws: FileHandlerError.self) {
            try await xci.install(file: nil)
        }

        // then
        assertDisplay(env: env, "There is no downloaded file to be installed")
    }

    @Test("Test promptForFile user cancelled with empty input")
    func testPromptForFileUserCancelled() {

        // given
        let env: MockedEnvironment = MockedEnvironment(readLine: MockedReadLine([""]))
        let deps = env.toDeps(log: log)
        let xci = XCodeInstall(log: log, deps: deps)

        // when
        #expect(throws: CLIError.self) {
            _ = try xci.promptForFile()
        }
    }

    @Test("Test promptForFile invalid non-numeric input")
    func testPromptForFileInvalidInput() {

        // given
        let env: MockedEnvironment = MockedEnvironment(readLine: MockedReadLine(["abc"]))
        let deps = env.toDeps(log: log)
        let xci = XCodeInstall(log: log, deps: deps)

        // when
        #expect(throws: CLIError.self) {
            _ = try xci.promptForFile()
        }
    }

    @Test("Test promptForFile out of bounds selection")
    func testPromptForFileOutOfBounds() {

        // given
        let env: MockedEnvironment = MockedEnvironment(readLine: MockedReadLine(["999"]))
        let deps = env.toDeps(log: log)
        let xci = XCodeInstall(log: log, deps: deps)

        // when (MockedFileHandler.downloadedFiles() returns ["name.pkg", "name.dmg"],
        // after filtering only .xip and .dmg remain => ["name.dmg"], so index 999 is out of bounds)
        #expect(throws: CLIError.self) {
            _ = try xci.promptForFile()
        }
    }

    @Test("Test Install with unsupported file type")
    func testInstallUnsupportedType() async throws {

        // given
        let env: MockedEnvironment = MockedEnvironment(progressBar: MockedProgressBar())
        let deps = env.toDeps(log: log)
        let xci = XCodeInstall(log: log, deps: deps)

        // when (test.txt is not a supported installation type)
        await #expect(throws: InstallerError.self) {
            try await xci.install(file: "test.txt")
        }

        // then
        assertDisplayStartsWith(env: env, "Unsupported installation type")
    }

    @Test("Test Install with generic shell error")
    func testInstallGenericError() async throws {

        // given
        let env: MockedEnvironment = MockedEnvironment(progressBar: MockedProgressBar())
        // configure the shell to throw a generic error
        env.shell.nextError = MockError.invalidMockData
        let deps = env.toDeps(log: log)
        let xci = XCodeInstall(log: log, deps: deps)

        // when (Command Line Tools dmg file is a supported type, fileExists returns true by default,
        // but the shell will throw when trying to mount the DMG)
        await #expect(throws: MockError.self) {
            try await xci.install(file: "Command Line Tools for Xcode 14.dmg")
        }

        // then
        assertDisplayStartsWith(env: env, "Error while installing")
    }

}
