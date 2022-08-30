//
//  InstallTest.swift
//  xcodeinstallTests
//
//  Created by Stormacq, Sebastien on 22/08/2022.
//

import XCTest
@testable import xcodeinstall

class InstallTest: XCTestCase {
    
    private var _installer: ShellInstaller?
    
    private func installer() -> ShellInstaller {
        return self._installer!
    }
    
    private func mockedShell() -> MockShell {
        return self._installer!.shell as! MockShell
    }
    
    override func setUpWithError() throws {
        self._installer = ShellInstaller(logger: Log(logLevel: .debug).defaultLogger)
        self._installer!.shell = MockShell()
        self._installer!.fileHandler = MockFilehandler()

    }

    override func tearDownWithError() throws {
        self._installer = nil
    }

    func testInstallInit() async throws {
        
        // given
        
        // when
        let ms2 = installer().shell
        
        // then
        XCTAssertNotNil(ms2)
        
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
        let mfh = installer().fileHandler as! MockFilehandler
        mfh.nextFileExist = true
        
        let srcFile = URL(fileURLWithPath: "/tmp/temp.xip")
        
        // when
        XCTAssertNoThrow(try installer().uncompressXIP(atPath: srcFile.path))
        
        // then
        XCTAssertEqual(mockedShell().command,  "/usr/bin/xip --expand \(srcFile.path)")
        
    }

    func testXIPNoFile() {
        
        // given
        let mfh = installer().fileHandler as! MockFilehandler
        mfh.nextFileExist = false
        
        let srcFile = URL(fileURLWithPath: "/tmp/temp.xip")

        // when
        // (give a file name that exists, otherwise, it throws an exception)
        XCTAssertThrowsError(try installer().uncompressXIP(atPath: srcFile.path))
        
        // then
        XCTAssertEqual(mockedShell().command,  "")
    }
    
    func testMoveApp() {
        // given
        let srcFile = "/Users/stormacq/.xcodeinstall/Downloads/Xcode 14 beta 5.app"
        let dstFile = "/Applications/Xcode 14 beta 5.app"
        
        // when
        XCTAssertNoThrow(try installer().moveApp(atPath: srcFile))
        
        // then
        let mfh = installer().fileHandler as! MockFilehandler
        XCTAssertEqual(mfh.moveSrc?.path, URL(fileURLWithPath: srcFile).path)
        XCTAssertEqual(mfh.moveDst?.path, URL(fileURLWithPath: dstFile).path)

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
        let fileName = "Xcode 14 beta.xip"
        
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
        let filePath = testDataDirectory().appendingPathComponent("Download List.json");
        let listData = try? Data(contentsOf: filePath)
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
        let download1 = DownloadList.Download(name: "", description: "", isReleased: 0, datePublished: "", dateCreated: "", dateModified: "", categories: [DownloadList.DownloadCategory(id: 0, name: "", sortOrder: 0)], files: [file1, file2, file3])
        let download2 = DownloadList.Download(name: "", description: "", isReleased: 0, datePublished: "", dateCreated: "", dateModified: "", categories: [DownloadList.DownloadCategory(id: 0, name: "", sortOrder: 0)], files: [file4, file5, file6])
        return DownloadList(creationTimestamp: "", resultCode: 0, resultString: "", userString: "", userLocale: "", protocolVersion: "", requestUrl: "", responseId: "", httpCode: 0, httpResponseHeaders: ["header" : "value"], downloads: [download1, download2])
    }
    
    func testFileMatchDownloadListExistsAndFileExists() {
        
        // given
        createDownloadList()
        let fileName = "/test/Xcode 14 beta.xip"
        
        let installer = installer()
        let mfh = installer.fileHandler as! MockFilehandler
        mfh.nextFileExist = true

        // when
        let existAndCorrect = installer.fileMatch(filePath: fileName)
    
        // then
        XCTAssertTrue(existAndCorrect)
    }
    
    func testFileMatchDownloadListExistsAndFileDoesNotExistInCache() {
        
        //given
        createDownloadList()
        let fileName = "/test/xxx.xip"
        
        let installer = installer()
        let mfh = installer.fileHandler as! MockFilehandler
        mfh.nextFileExist = false

        // when
        let fileExists = installer.fileMatch(filePath: fileName)
    
        // then
        XCTAssertFalse(fileExists)
    }
    
    func testFileMatchDownloadListDoesNotExistAndFileExists() {
        
        //given
        deleteDownloadList()
        let fileName = "/test/Xcode 14 beta.xip"

        let installer = installer()
        let mfh = installer.fileHandler as! MockFilehandler
        mfh.nextFileExist = true

        // when
        let fileExists = installer.fileMatch(filePath: fileName)
    
        // then
        XCTAssertTrue(fileExists)
    }
    
    private func createDownloadList() {

        let log = Log().defaultLogger
        let fsh = FileSecretsHandler(logger: log)
        let fm  = FileManager.default

        // copy test file at destination
        
        // first remove it if it exists
        if fm.fileExists(atPath: fsh.downloadListPath.path) {
            XCTAssertNoThrow(try fm.removeItem(at: fsh.downloadListPath))
        }
        // then copy
        let testFilePath = testDataDirectory().appendingPathComponent("Download List.json");
        XCTAssertNoThrow(try fm.copyItem(at: testFilePath, to: fsh.downloadListPath))

    }
    
    private func deleteDownloadList() {

        let log = Log().defaultLogger
        let fsh = FileSecretsHandler(logger: log)
        let fm  = FileManager.default

        // remove test file from destination
        if fm.fileExists(atPath: fsh.downloadListPath.path) {
            XCTAssertNoThrow(try fm.removeItem(at: fsh.downloadListPath))
        }
    }
    
    func testInstallXcode() async {
        
        // given
        let file = "/test/Xcode 14 beta.xip"
        
        // when
        do {
            try await installer().install(file: file, progress: MockedProgressBar())
        } catch {
            // check no error is thrown
            print("\(error)")
            XCTAssert(false)
        }
        
        // then
    }

    func testInstallCommandLineTools() async {
        
        // given
        let file = "/test/Command Line Tools for Xcode 14 beta 5.dmg"
        
        // when
        do {
            try await installer().install(file: file, progress: MockedProgressBar())
        } catch {
            // check no error is thrown
            print("\(error)")
            XCTAssert(false)
        }
        
        // then
    }

    func testInstallFileDoesNotExist() async {
        
        let mfh = installer().fileHandler as! MockFilehandler
        mfh.nextFileExist = false
        
        // given
        let file = "/test/Command Line Tools for Xcode 14 beta 5.dmg"
        
        // when
        do {
            try await installer().install(file: file, progress: MockedProgressBar())

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
        
        let mfh = installer().fileHandler as! MockFilehandler
        mfh.nextFileExist = true
        
        // given
        let file = "/test/test.zip"
        
        // when
        do {
            try await installer().install(file: file, progress: MockedProgressBar())

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
