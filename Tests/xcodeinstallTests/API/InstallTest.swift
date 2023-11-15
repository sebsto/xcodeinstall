//
//  InstallTest.swift
//  xcodeinstallTests
//
//  Created by Stormacq, Sebastien on 22/08/2022.
//

import XCTest
import CLIlib
@testable import xcodeinstall

class InstallTest: XCTestCase {
    
    private var installer = ShellInstaller()
    
    private func mockedShell() -> MockShell {
        return (env.shell as! MockShell)
    }
        
    override func setUpWithError() throws {
        env = Environment.mock

        let mockedShell = (env.shell as! MockShell)
        mockedShell.command = ""
    }

    func testInstallUnsupportedFile() async throws {
        
        // given
        let pkgName = "invalid package"
        
        // when
        let result : SupportedInstallation = SupportedInstallation.supported(pkgName)
        
        // then
        XCTAssertTrue(result == .unsuported)
        
    }

    func testInstallSupportFileXcode() async throws {
        
        // given
        let pkgName = "Xcode 14 beta 5.xip"
        
        // when
        let result : SupportedInstallation = SupportedInstallation.supported(pkgName)
        
        // then
        XCTAssertTrue(result == .xCode)
    }

    func testInstallSupportFileCommandLineTools() async throws {
        
        // given
        let pkgName = "Command Line Tools for Xcode 14 beta 5.dmg"
        
        // when
        let result : SupportedInstallation = SupportedInstallation.supported(pkgName)
        
        // then
        XCTAssertTrue(result == .xCodeCommandLineTools)
        
    }

    func testXIP() {
        
        // given
        let mfh = env.fileHandler as! MockedFileHandler
        mfh.nextFileExist = true
        
        let srcFile = URL(fileURLWithPath: "/tmp/temp.xip")
        
        // when
        XCTAssertNoThrow(try installer.uncompressXIP(atURL: srcFile))
        
        // then
        XCTAssertTrue(mockedShell().command.contains("/usr/bin/xip --expand \"\(srcFile.path)\""))
        XCTAssertTrue(mockedShell().command.hasPrefix("pushd"))
        XCTAssertTrue(mockedShell().command.hasSuffix("popd"))

    }

    func testXIPNoFile() {
        
        // given
        (env.fileHandler as! MockedFileHandler).nextFileExist = false

        
        let srcFile = URL(fileURLWithPath: "/tmp/temp.xip")

        // when
        // (give a file name that exists, otherwise, it throws an exception)
        XCTAssertThrowsError(try installer.uncompressXIP(atURL: srcFile))
        
        // then
        XCTAssertEqual(mockedShell().command,  "")
    }
    
    func testMoveApp() {
        // given
        let src = URL(fileURLWithPath: "/Users/stormacq/.xcodeinstall/Downloads/Xcode 14 beta 5.app")
        let dst = URL(fileURLWithPath: "/Applications/Xcode 14 beta 5.app")
        
        // when
        XCTAssertNoThrow(try installer.moveApp(at: src))
        
        // then
        let mfh = env.fileHandler as! MockedFileHandler
        XCTAssertEqual(mfh.moveSrc?.path, src.path)
        XCTAssertEqual(mfh.moveDst?.path, dst.path)

    }
    
    func testFindInDownloadListFileExists() {
        
        // given
        let dl = createMockedDownloadList()
        let fileName = "doc.pdf"
        
        // when
        let file = dl.find(fileName: fileName)
        
        // then
        XCTAssertNotNil(file)
        XCTAssertEqual(file?.filename, fileName)
    }

    func testFindInDownloadListFileDoesNotExist() {
        
        // given
        let dl = createMockedDownloadList()
        let fileName = "xxx.pdf"
        
        // when
        let file = dl.find(fileName: fileName)
        
        // then
        XCTAssertNil(file)
    }
    
    func testFindInDownloadWithrealListFileExists() {
        // given
        let dl = loadDownloadListFromFile()
        let fileName = "Xcode 14.xip"
        
        // when
        let file = dl.find(fileName: fileName)
        
        // then
        XCTAssertNotNil(file)
        XCTAssertEqual(file?.filename, fileName)

    }

    func testFindInDownloadWithrealListFileDoesNotExist() {
        // given
        let dl = loadDownloadListFromFile()
        let fileName = "xxx.pdf"
        
        // when
        let file = dl.find(fileName: fileName)
        
        // then
        XCTAssertNil(file)
    }
    
    private func loadDownloadListFromFile() -> DownloadList {
        
        // load list from test file
        let listData = try? loadTestData(file: .downloadList)
        XCTAssertNotNil(listData)

        // decode the JSON
        let list: DownloadList? = try? JSONDecoder().decode(DownloadList.self, from: listData!)
        XCTAssertNotNil(list)
        
        return list!
    }

    
    private func createMockedDownloadList() -> DownloadList {

        let file1 = DownloadList.File(filename: "test.zip", displayName: "", remotePath: "", fileSize: 1, sortOrder: 0, dateCreated: "", dateModified: "", fileFormat: DownloadList.FileFormat(fileExtension: "zip", description: "zip"))
        let file2 = DownloadList.File(filename: "readme.txt", displayName: "", remotePath: "", fileSize: 1, sortOrder: 0, dateCreated: "", dateModified: "", fileFormat: DownloadList.FileFormat(fileExtension: "zip", description: "zip"))
        let file3 = DownloadList.File(filename: "doc.pdf", displayName: "", remotePath: "", fileSize: 1, sortOrder: 0, dateCreated: "", dateModified: "", fileFormat: DownloadList.FileFormat(fileExtension: "zip", description: "zip"))
        let file4 = DownloadList.File(filename: "test2.zip", displayName: "", remotePath: "", fileSize: 1, sortOrder: 0, dateCreated: "", dateModified: "", fileFormat: DownloadList.FileFormat(fileExtension: "zip", description: "zip"))
        let file5 = DownloadList.File(filename: "readme2.txt", displayName: "", remotePath: "", fileSize: 1, sortOrder: 0, dateCreated: "", dateModified: "", fileFormat: DownloadList.FileFormat(fileExtension: "zip", description: "zip"))
        let file6 = DownloadList.File(filename: "doc2.pdf", displayName: "", remotePath: "", fileSize: 1, sortOrder: 0, dateCreated: "", dateModified: "", fileFormat: DownloadList.FileFormat(fileExtension: "zip", description: "zip"))
        let download1 = DownloadList.Download(id: "01", name: "", description: "", isReleased: 0, datePublished: "", dateCreated: "", dateModified: "", categories: [DownloadList.DownloadCategory(id: 0, name: "", sortOrder: 0)], files: [file1, file2, file3], isRelatedSeed: false)
        let download2 = DownloadList.Download(id: "02", name: "", description: "", isReleased: 0, datePublished: "", dateCreated: "", dateModified: "", categories: [DownloadList.DownloadCategory(id: 0, name: "", sortOrder: 0)], files: [file4, file5, file6], isRelatedSeed: false)
        return DownloadList(creationTimestamp: "", resultCode: 0, resultString: "", userString: "", userLocale: "", protocolVersion: "", requestUrl: "", responseId: "", httpCode: 0, httpResponseHeaders: ["header" : "value"], downloadHost: "", downloads: [download1, download2])
    }
    
    func testFileMatchDownloadListExistsAndFileExists() {
        
        // given
        createDownloadList()
        let file = URL(fileURLWithPath: "/test/Xcode 14 beta.xip")
        
        let mfh = env.fileHandler as! MockedFileHandler
        mfh.nextFileExist = true

        // when
        let existAndCorrect = installer.fileMatch(file: file)
    
        // then
        XCTAssertTrue(existAndCorrect)
    }
    
    func testFileMatchDownloadListExistsAndFileDoesNotExistInCache() {
        
        //given
        createDownloadList()
        let file = URL(fileURLWithPath: "/test/xxx.xip")
        
        let mfh = env.fileHandler as! MockedFileHandler
        mfh.nextFileExist = false

        // when
        let fileExists = installer.fileMatch(file: file)
    
        // then
        XCTAssertFalse(fileExists)
    }
    
    func testFileMatchDownloadListDoesNotExistAndFileExists() {
        
        //given
        deleteDownloadList()
        let file = URL(fileURLWithPath: "/test/Xcode 14 beta.xip")

        let mfh = env.fileHandler as! MockedFileHandler
        mfh.nextFileExist = true

        // when
        let fileExists = installer.fileMatch(file: file)
    
        // then
        XCTAssertTrue(fileExists)
    }
    
    func testInstallXcode() async {
        
        // given
        let file = URL(fileURLWithPath: "/test/Xcode 14 beta.xip")
        
        // when
        do {

            try await installer.install(file: file)
            XCTAssert(false)
        } catch InstallerError.xCodeMoveInstallationError {
            //expected
        } catch {
            // check no error is thrown
            print("\(error)")
            XCTAssert(false)
        }
        
        // then
    }

    func testInstallCommandLineTools() async {
        
        // given
        let file = URL(fileURLWithPath: "/test/Command Line Tools for Xcode 14 beta 5.dmg")
        
        // when
        do {
            try await installer.install(file: file)
        } catch {
            // check no error is thrown
            print("\(error)")
            XCTAssert(false)
        }
        
        // then
    }

    func testInstallFileDoesNotExist() async {
        
        let mfh = env.fileHandler as! MockedFileHandler
        mfh.nextFileExist = false
        
        // given
        let file = URL(fileURLWithPath: "/test/Command Line Tools for Xcode 14 beta 5.dmg")
        
        // when
        do {
            try await installer.install(file: file)

            // then
            XCTAssert(false, "This method must throw an error")
            
        } catch InstallerError.fileDoesNotExistOrIncorrect {
            // expected
        } catch {
            // check no other error is thrown
            print("\(error)")
            XCTAssert(false)
        }
        
    }

    func testInstallFileUnsuported() async {
        
        let mfh = env.fileHandler as! MockedFileHandler
        mfh.nextFileExist = true
        
        // given
        let file = URL(fileURLWithPath: "/test/test.zip")
        
        // when
        do {
            try await installer.install(file: file)

            // then
            XCTAssert(false, "This method must throw an error")
            
        } catch InstallerError.unsupportedInstallation {
            // expected
        } catch {
            // check no other error is thrown
            print("\(error)")
            XCTAssert(false)
        }
        
    }

}
