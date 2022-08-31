//
//  CLIDownloadTest.swift
//  xcodeinstallTests
//
//  Created by Stormacq, Sebastien on 22/08/2022.
//

import XCTest
import ArgumentParser
@testable import xcodeinstall

class CLIDownloadTest: CLITest {
    
    func testDownload() async throws {
        
        // given
        
        let mockedReadline = MockedReadLine(["0"])
        var xci = xcodeinstall(input: mockedReadline)
        xci.downloader = MockAppleDownloader()
        (xci.fileHandler as! MockFileHandler).nextFileCorrect = true
        
        
        let download = try parse(MainCommand.Download.self, [
            "download",
            "--verbose",
            "--force",
            "--only-xcode",
            "--xcode-version",
            "14",
            "--most-recent-first",
            "--date-published",
        ])
        
        
        // when
        do {
            // try await download.run() // can not call this as I can not inject all the mocks
            try await xci.download(fileName: nil, force: true, xCodeOnly: true, majorVersion: "14", sortMostRecentFirst: true, datePublished: true)
        } catch {
            // then
            XCTAssert(false, "unexpected exception : \(error)")
        }
        
        // test parsing of commandline arguments
        XCTAssert(download.globalOptions.verbose)
        XCTAssert(download.downloadListOptions.force)
        XCTAssert(download.downloadListOptions.onlyXcode)
        XCTAssert(download.downloadListOptions.xCodeVersion == "14")
        XCTAssert(download.downloadListOptions.mostRecentFirst)
        XCTAssert(download.downloadListOptions.datePublished)
        
        // mocked list succeeded
        assertDisplay("✅ file downloaded")
    }
    
    func testDownloadWithError() async throws {
        
        // given
        let xci = xcodeinstall()
        
        // when
        do {
            try await xci.download(fileName: nil, force: true, xCodeOnly: true, majorVersion: "14", sortMostRecentFirst: true, datePublished: true)
            XCTAssert(false)
            
        } catch XCodeInstallError.configurationError {
            
            // then
            XCTAssert(true)
        }
    }
    
    func testDownloadWithCorrectFileName() async throws {
        
        // given
        
        var xci = xcodeinstall()
        xci.downloader = MockAppleDownloader()
        (xci.fileHandler as! MockFileHandler).nextFileCorrect = true
        let fileName = "Xcode 14 beta.xip"

        let download = try parse(MainCommand.Download.self, [
            "download",
            "--name",
            fileName
        ])
        
        // when
        do {


            // try await download.run() // can not call this as I can not inject all the mocks
            try await xci.download(fileName: fileName, force: false, xCodeOnly: false, majorVersion: "", sortMostRecentFirst: false, datePublished: false)
        } catch {
            // then
            XCTAssert(false, "unexpected exception : \(error)")
        }
        
        // test parsing of commandline arguments
        XCTAssertEqual(download.name, fileName)
        XCTAssertFalse(download.globalOptions.verbose)
        XCTAssertFalse(download.downloadListOptions.force)
        XCTAssertFalse(download.downloadListOptions.onlyXcode)
        XCTAssertFalse(download.downloadListOptions.mostRecentFirst)
        XCTAssertFalse(download.downloadListOptions.datePublished)
        
        // mocked list succeeded
        assertDisplay("✅ \(fileName) downloaded")
    }

    func testDownloadWithIncorrectFileName() async throws {
        
        // given
        
        var xci = xcodeinstall()
        xci.downloader = MockAppleDownloader()
        (xci.fileHandler as! MockFileHandler).nextFileCorrect = true
        let fileName = "xxx.xip"

        let download = try parse(MainCommand.Download.self, [
            "download",
            "--name",
            fileName
        ])
        
        // when
        do {


            // try await download.run() // can not call this as I can not inject all the mocks
            try await xci.download(fileName: fileName, force: false, xCodeOnly: false, majorVersion: "", sortMostRecentFirst: false, datePublished: false)
        } catch {
            // then
            XCTAssert(false, "unexpected exception : \(error)")
        }
        
        // test parsing of commandline arguments
        XCTAssertEqual(download.name, fileName)
        XCTAssertFalse(download.globalOptions.verbose)
        XCTAssertFalse(download.downloadListOptions.force)
        XCTAssertFalse(download.downloadListOptions.onlyXcode)
        XCTAssertFalse(download.downloadListOptions.mostRecentFirst)
        XCTAssertFalse(download.downloadListOptions.datePublished)
        
        // mocked list succeeded
        assertDisplay("🛑 Unknown file name : xxx.xip")
    }

}
