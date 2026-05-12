import ArgumentParser
import Logging
import Testing

@testable import xcodeinstall

extension CLITests {

    @Test("Test switch command parsing")
    func testSwitchCommandParsing() throws {
        let cmd = try parse(MainCommand.SwitchVersion.self, ["switch", "16.2"])
        #expect(cmd.version == "16.2")
    }

    @Test("Test switch command parsing without version")
    func testSwitchCommandParsingNoVersion() throws {
        let cmd = try parse(MainCommand.SwitchVersion.self, ["switch"])
        #expect(cmd.version == nil)
    }

    @Test("Test switch to valid version")
    func testSwitchToValidVersion() async throws {
        // given
        let mfh = MockedFileHandler()
        mfh.installedXcodes = ["Xcode-15.0.app", "Xcode-16.2.app"]
        mfh.nextIsSymlink = true
        let env = MockedEnvironment(fileHandler: mfh)
        let deps = env.toDeps(log: log)
        let xci = XCodeInstall(log: log, deps: deps)

        // when
        try await xci.switchVersion(to: "16.2")

        // then
        #expect(mfh.symlinkLink?.path == "/Applications/Xcode.app")
        #expect(mfh.symlinkTarget?.path == "/Applications/Xcode-16.2.app")
    }

    @Test("Test switch to non-existent version")
    func testSwitchToNonExistentVersion() async {
        // given
        let mfh = MockedFileHandler()
        mfh.installedXcodes = ["Xcode-15.0.app"]
        let env = MockedEnvironment(fileHandler: mfh)
        let deps = env.toDeps(log: log)
        let xci = XCodeInstall(log: log, deps: deps)

        // when
        let error = await #expect(throws: InstallerError.self) {
            try await xci.switchVersion(to: "99.0")
        }

        // then
        #expect(error == InstallerError.xcodeVersionNotInstalled("99.0"))
    }

    @Test("Test switch with no installed versions")
    func testSwitchNoInstalledVersions() async {
        // given
        let mfh = MockedFileHandler()
        mfh.installedXcodes = []
        let env = MockedEnvironment(fileHandler: mfh)
        let deps = env.toDeps(log: log)
        let xci = XCodeInstall(log: log, deps: deps)

        // when
        let error = await #expect(throws: InstallerError.self) {
            try await xci.switchVersion(to: nil)
        }

        // then
        #expect(error == InstallerError.noInstalledXcodeVersions)
    }

    @Test("Test switch interactive prompt")
    func testSwitchInteractivePrompt() async throws {
        // given - user selects index 1
        let mfh = MockedFileHandler()
        mfh.installedXcodes = ["Xcode-15.0.app", "Xcode-16.2.app"]
        mfh.nextIsSymlink = true
        let env = MockedEnvironment(fileHandler: mfh, readLine: MockedReadLine(["1"]))
        let deps = env.toDeps(log: log)
        let xci = XCodeInstall(log: log, deps: deps)

        // when
        try await xci.switchVersion(to: nil)

        // then - should activate version at index 1 (16.2)
        #expect(mfh.symlinkLink?.path == "/Applications/Xcode.app")
        #expect(mfh.symlinkTarget?.path == "/Applications/Xcode-16.2.app")
    }
}
