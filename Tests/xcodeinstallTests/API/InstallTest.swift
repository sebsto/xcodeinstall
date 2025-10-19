//
//  InstallTest.swift
//  xcodeinstallTests
//
//  Created by Stormacq, Sebastien on 22/08/2022.
//

import CLIlib
import Foundation
import Logging
import Testing

@testable import xcodeinstall

#if canImport(FoundationEssentials)
import FoundationEssentials
#endif

final class InstallTest {

    let log = Logger(label: "InstallTest")
    // private var installer: ShellInstaller
    private var env: Environment = MockedEnvironment()

    // override func setUpWithError() throws {
    //     installer = ShellInstaller(env: env)
    // }

    @Test("Test Install Unsupported File")
    func testInstallUnsupportedFile() async throws {

        // given
        let pkgName = "invalid package"

        // when
        let result: SupportedInstallation = SupportedInstallation.supported(pkgName)

        // then
        #expect(result == .unsuported)

    }

    @Test("Test Install Support File Xcode")
    func testInstallSupportFileXcode() async throws {

        // given
        let pkgName = "Xcode 14 beta 5.xip"

        // when
        let result: SupportedInstallation = SupportedInstallation.supported(pkgName)

        // then
        #expect(result == .xCode)
    }

    @Test("Test Install Support File Command Line Tools")
    func testInstallSupportFileCommandLineTools() async throws {

        // given
        let pkgName = "Command Line Tools for Xcode 14 beta 5.dmg"

        // when
        let result: SupportedInstallation = SupportedInstallation.supported(pkgName)

        // then
        #expect(result == .xCodeCommandLineTools)

    }

    @Test("Test Install Pkg Uses Sudo")
    func testInstallPkgUsesSudo() async throws {
        // given
        let mfh = env.fileHandler as! MockedFileHandler
        mfh.nextFileExist = true

        let srcFile = URL(fileURLWithPath: "/tmp/temp.pkg")

        // when
        let _ = await #expect(throws: Never.self) {
            let installer = ShellInstaller(env: &env, log: log)
            let _ = try await installer.installPkg(atURL: srcFile)
        }

        // then
        let runRecorder = MockedEnvironment.runRecorder
        #expect(runRecorder.containsExecutable("/usr/bin/sudo"))
        #expect(runRecorder.containsArgument("/usr/sbin/installer"))
        #expect(runRecorder.containsArgument(srcFile.path))
        #expect(runRecorder.containsArgument("-pkg"))
        #expect(runRecorder.containsArgument("-target"))
        #expect(runRecorder.containsArgument("/"))
    }

    //    func testXIP() async {
    //
    //        // given
    //        let mfh = env.fileHandler as! MockedFileHandler
    //        mfh.nextFileExist = true
    //
    //        let srcFile = URL(fileURLWithPath: "/tmp/temp.xip")
    //
    //        // when
    //        do {
    //            let installer = ShellInstaller(env: &env)
    //            let _ = try await installer.uncompressXIP(atURL: srcFile)
    //        } catch {
    //            XCTFail("uncompressXIP generated an error : \(error)")
    //        }
    //
    //        // then
    //        let runRecorder = MockedEnvironment.runRecorder
    //        XCTAssertTrue(runRecorder.containsExecutable("/usr/sbin/pkgutil"))
    //        XCTAssertTrue(runRecorder.containsArgument("--expand-full"))
    //        XCTAssertTrue(runRecorder.containsArgument(srcFile.path))
    //        XCTAssertTrue(runRecorder.containsArgument("Xcode.app"))
    //    }

    @Test("Test XIP No File")
    func testXIPNoFile() async {

        // given
        (env.fileHandler as! MockedFileHandler).nextFileExist = false

        let srcFile = URL(fileURLWithPath: "/tmp/temp.xip")

        // when
        // (give a file name that exists, otherwise, it throws an exception)
        let error = await #expect(throws: InstallerError.self) {
            let installer = ShellInstaller(env: &self.env, log: log)
            let _ = try await installer.uncompressXIP(atURL: srcFile)
        }
        #expect(error == InstallerError.fileDoesNotExistOrIncorrect)
    }
    @Test("Test Move App")
    func testMoveApp() async {
        // given
        let src = URL(fileURLWithPath: "/Users/stormacq/.xcodeinstall/Downloads/Xcode 14 beta 5.app")
        let dst = URL(fileURLWithPath: "/Applications/Xcode 14 beta 5.app")

        // when
        let _ = await #expect(throws: Never.self) {
            let installer = ShellInstaller(env: &self.env, log: log)
            _ = try await installer.moveApp(at: src)
        }

        // then
        let mfh = env.fileHandler as! MockedFileHandler
        #expect(mfh.moveSrc?.path == src.path)
        #expect(mfh.moveDst?.path == dst.path)

    }

    @Test("Test Find In Download List File Exists")
    func testFindInDownloadListFileExists() {

        // given
        let dl = createMockedDownloadList()
        let fileName = "doc.pdf"

        // when
        let file = dl.find(fileName: fileName)

        // then
        #expect(file != nil)
        #expect(file?.filename == fileName)
    }

    @Test("Test Find In Download List File Does Not Exist")
    func testFindInDownloadListFileDoesNotExist() {

        // given
        let dl = createMockedDownloadList()
        let fileName = "xxx.pdf"

        // when
        let file = dl.find(fileName: fileName)

        // then
        #expect(file == nil)
    }

    @Test("Test Find In Download With Real List File Exists")
    func testFindInDownloadWithrealListFileExists() {
        // given
        let dl = loadDownloadListFromFile()
        let fileName = "Xcode 14.xip"

        // when
        let file = dl.find(fileName: fileName)

        // then
        #expect(file != nil)
        #expect(file?.filename == fileName)

    }

    @Test("Test Find In Download With Real List File Does Not Exist")
    func testFindInDownloadWithrealListFileDoesNotExist() {
        // given
        let dl = loadDownloadListFromFile()
        let fileName = "xxx.pdf"

        // when
        let file = dl.find(fileName: fileName)

        // then
        #expect(file == nil)
    }

    private func loadDownloadListFromFile() -> DownloadList {

        // load list from test file
        let listData = try? loadTestData(file: .downloadList)
        #expect(listData != nil)

        // decode the JSON
        let list: DownloadList? = try? JSONDecoder().decode(DownloadList.self, from: listData!)
        #expect(list != nil)

        return list!
    }

    private func createMockedDownloadList() -> DownloadList {

        let file1 = DownloadList.File(
            filename: "test.zip",
            displayName: "",
            remotePath: "",
            fileSize: 1,
            sortOrder: 0,
            dateCreated: "",
            dateModified: "",
            fileFormat: DownloadList.FileFormat(fileExtension: "zip", description: "zip")
        )
        let file2 = DownloadList.File(
            filename: "readme.txt",
            displayName: "",
            remotePath: "",
            fileSize: 1,
            sortOrder: 0,
            dateCreated: "",
            dateModified: "",
            fileFormat: DownloadList.FileFormat(fileExtension: "zip", description: "zip")
        )
        let file3 = DownloadList.File(
            filename: "doc.pdf",
            displayName: "",
            remotePath: "",
            fileSize: 1,
            sortOrder: 0,
            dateCreated: "",
            dateModified: "",
            fileFormat: DownloadList.FileFormat(fileExtension: "zip", description: "zip")
        )
        let file4 = DownloadList.File(
            filename: "test2.zip",
            displayName: "",
            remotePath: "",
            fileSize: 1,
            sortOrder: 0,
            dateCreated: "",
            dateModified: "",
            fileFormat: DownloadList.FileFormat(fileExtension: "zip", description: "zip")
        )
        let file5 = DownloadList.File(
            filename: "readme2.txt",
            displayName: "",
            remotePath: "",
            fileSize: 1,
            sortOrder: 0,
            dateCreated: "",
            dateModified: "",
            fileFormat: DownloadList.FileFormat(fileExtension: "zip", description: "zip")
        )
        let file6 = DownloadList.File(
            filename: "doc2.pdf",
            displayName: "",
            remotePath: "",
            fileSize: 1,
            sortOrder: 0,
            dateCreated: "",
            dateModified: "",
            fileFormat: DownloadList.FileFormat(fileExtension: "zip", description: "zip")
        )
        let download1 = DownloadList.Download(
            id: "01",
            name: "",
            description: "",
            isReleased: 0,
            datePublished: "",
            dateCreated: "",
            dateModified: "",
            categories: [DownloadList.DownloadCategory(id: 0, name: "", sortOrder: 0)],
            files: [file1, file2, file3],
            isRelatedSeed: false
        )
        let download2 = DownloadList.Download(
            id: "02",
            name: "",
            description: "",
            isReleased: 0,
            datePublished: "",
            dateCreated: "",
            dateModified: "",
            categories: [DownloadList.DownloadCategory(id: 0, name: "", sortOrder: 0)],
            files: [file4, file5, file6],
            isRelatedSeed: false
        )
        return DownloadList(
            creationTimestamp: "",
            resultCode: 0,
            resultString: "",
            userString: "",
            userLocale: "",
            protocolVersion: "",
            requestUrl: "",
            responseId: "",
            httpCode: 0,
            httpResponseHeaders: ["header": "value"],
            downloadHost: "",
            downloads: [download1, download2]
        )
    }

    @Test("Test File Match Download List Exists And File Exists")
    func testFileMatchDownloadListExistsAndFileExists() throws {

        // given
        try createDownloadList()
        let file = URL(fileURLWithPath: "/test/Xcode 14 beta.xip")

        let mfh = env.fileHandler as! MockedFileHandler
        mfh.nextFileExist = true

        // when
        let installer = ShellInstaller(env: &self.env, log: log)
        let existAndCorrect = installer.fileMatch(file: file)

        // then
        #expect(existAndCorrect)
    }

    @Test("Test File Match Download List Exists And File Does Not Exist In Cache")
    func testFileMatchDownloadListExistsAndFileDoesNotExistInCache() throws {

        //given
        try createDownloadList()
        let file = URL(fileURLWithPath: "/test/xxx.xip")

        let mfh = env.fileHandler as! MockedFileHandler
        mfh.nextFileExist = false

        // when
        let installer = ShellInstaller(env: &self.env, log: log)
        let fileExists = installer.fileMatch(file: file)

        // then
        #expect(!fileExists)
    }

    @Test("Test File Match Download List Does Not Exist And File Exists")
    func testFileMatchDownloadListDoesNotExistAndFileExists() throws {

        //given
        try deleteDownloadList()
        let file = URL(fileURLWithPath: "/test/Xcode 14 beta.xip")

        let mfh = env.fileHandler as! MockedFileHandler
        mfh.nextFileExist = true

        // when
        let installer = ShellInstaller(env: &self.env, log: log)
        let fileExists = installer.fileMatch(file: file)

        // then
        #expect(fileExists)
    }

    //    func testInstallXcode() async {
    //
    //        // given
    //        let file = URL(fileURLWithPath: "/tmp/Xcode 14 beta.xip")
    //
    //        // when
    //        do {
    //
    //            let installer = ShellInstaller(env: &self.env)
    //            try await installer.install(file: file)
    //            XCTAssert(false)
    //        } catch InstallerError.xCodeMoveInstallationError {
    //            //expected
    //        } catch {
    //            // check no error is thrown
    //            print("\(error)")
    //            XCTAssert(false)
    //        }
    //
    //        // then
    //    }

    #if os(macOS)
    // on linux, hdiutil is not available. This test fails with
    //  Executable "/usr/bin/hdiutil" is not found or cannot be executed.
    @Test("Test Install Command Line Tools")
    func testInstallCommandLineTools() async {

        // given
        (self.env.fileHandler as! MockedFileHandler).nextFileExist = false
        let file = URL(fileURLWithPath: "/test/Command Line Tools for Xcode 14 beta 5.dmg")

        // when
        let error = await #expect(throws: InstallerError.self) {
            let installer = ShellInstaller(env: &self.env, log: log)
            try await installer.install(file: file)
        }
        #expect(error == InstallerError.fileDoesNotExistOrIncorrect)
    }
    #endif

    @Test("Test Install File Does Not Exist")
    func testInstallFileDoesNotExist() async {

        let mfh = env.fileHandler as! MockedFileHandler
        mfh.nextFileExist = false

        // given
        let file = URL(fileURLWithPath: "/test/Command Line Tools for Xcode 14 beta 5.dmg")

        // when
        let error = await #expect(throws: InstallerError.self) {
            let installer = ShellInstaller(env: &self.env, log: log)
            try await installer.install(file: file)
        }
        #expect(error == InstallerError.fileDoesNotExistOrIncorrect)

    }

    @Test("Test Install File Unsupported")
    func testInstallFileUnsuported() async {

        let mfh = env.fileHandler as! MockedFileHandler
        mfh.nextFileExist = true

        // given
        let file = URL(fileURLWithPath: "/test/test.zip")

        // when
        let error = await #expect(throws: InstallerError.self) {
            let installer = ShellInstaller(env: &self.env, log: log)
            try await installer.install(file: file)
        }
        #expect(error == InstallerError.unsupportedInstallation)

    }

}
