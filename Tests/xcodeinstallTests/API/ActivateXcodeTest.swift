import Foundation
import Logging
import Testing

@testable import xcodeinstall

final class ActivateXcodeTest {

    let log = Logger(label: "ActivateXcodeTest")
    private var env = MockedEnvironment()

    @Test("Activate Xcode creates symlink and runs xcode-select")
    func testActivateXcodeHappyPath() async throws {
        // given
        let mfh = env.fileHandler as! MockedFileHandler
        mfh.nextIsSymlink = true  // no existing real Xcode.app blocking

        let installer = ShellInstaller(
            fileHandler: env.fileHandler,
            progressBar: env.progressBar,
            shellExecutor: env.shell,
            log: log
        )

        // when
        try await installer.activateXcode(version: "16.2")

        // then
        #expect(mfh.symlinkLink?.path == "/Applications/Xcode.app")
        #expect(mfh.symlinkTarget?.path == "/Applications/Xcode-16.2.app")

        let runRecorder = MockedShell.runRecorder
        #expect(runRecorder.containsExecutable("/usr/bin/sudo"))
        #expect(runRecorder.containsArgument("/usr/bin/xcode-select"))
        #expect(runRecorder.containsArgument("-s"))
        #expect(runRecorder.containsArgument("/Applications/Xcode-16.2.app"))
    }

    @Test("Activate Xcode replaces existing symlink")
    func testActivateXcodeReplacesSymlink() async throws {
        // given
        let mfh = env.fileHandler as! MockedFileHandler
        mfh.nextIsSymlink = true  // existing Xcode.app is already a symlink

        let installer = ShellInstaller(
            fileHandler: env.fileHandler,
            progressBar: env.progressBar,
            shellExecutor: env.shell,
            log: log
        )

        // when
        try await installer.activateXcode(version: "15.0")

        // then — symlink is updated
        #expect(mfh.symlinkLink?.path == "/Applications/Xcode.app")
        #expect(mfh.symlinkTarget?.path == "/Applications/Xcode-15.0.app")
    }

    @Test("Activate Xcode throws when existing Xcode.app is not a symlink")
    func testActivateXcodeRealDirectoryThrows() async {
        // given
        let mfh = env.fileHandler as! MockedFileHandler
        mfh.nextIsSymlink = false  // existing Xcode.app is a real directory
        mfh.nextFileExist = true

        let installer = ShellInstaller(
            fileHandler: env.fileHandler,
            progressBar: env.progressBar,
            shellExecutor: env.shell,
            log: log
        )

        // when
        let error = await #expect(throws: InstallerError.self) {
            try await installer.activateXcode(version: "16.2")
        }

        // then
        #expect(error == InstallerError.existingXcodeAppIsNotSymlink)
        #expect(mfh.symlinkLink == nil)
    }
}
