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
        (env.readLine as! MockedReadLine).input = ["0"]
        
        let download = try parse(MainCommand.Download.self, [
            "download",
            "--verbose",
            "--xcode-version",
            "14",
            "--most-recent-first",
            "--date-published",
        ])
        
        
        // when
        do {
            try await download.run() 
        } catch {
            // then
            XCTAssert(false, "unexpected exception : \(error)")
        }
        
        // test parsing of commandline arguments
        XCTAssert(download.globalOptions.verbose)
        XCTAssert(download.downloadListOptions.xCodeVersion == "14")
        XCTAssert(download.downloadListOptions.mostRecentFirst)
        XCTAssert(download.downloadListOptions.datePublished)
        
        // mocked list succeeded
        assertDisplay("✅ file downloaded")
    }
    
    func testDownloadWithCorrectFileName() async throws {
        
        // given
        let fileName = "Xcode 14.xip"

        let download = try parse(MainCommand.Download.self, [
            "download",
            "--name",
            fileName
        ])
        
        // when
        do {

            try await download.run()

        } catch {
            // then
            XCTAssert(false, "unexpected exception : \(error)")
        }
        
        // test parsing of commandline arguments
        XCTAssertEqual(download.name, fileName)
        XCTAssertFalse(download.globalOptions.verbose)
        XCTAssertFalse(download.downloadListOptions.mostRecentFirst)
        XCTAssertFalse(download.downloadListOptions.datePublished)
        
        // mocked list succeeded
        assertDisplay("✅ \(fileName) downloaded")
    }

    func testDownloadWithIncorrectFileName() async throws {

        // given
        let fileName = "xxx.xip"

        let download = try parse(MainCommand.Download.self, [
            "download",
            "--name",
            fileName
        ])

        // when
        do {
            try await download.run()
        } catch {
            // then
            XCTAssert(false, "unexpected exception : \(error)")
        }

        // test parsing of commandline arguments
        XCTAssertEqual(download.name, fileName)
        XCTAssertFalse(download.globalOptions.verbose)
        XCTAssertFalse(download.downloadListOptions.mostRecentFirst)
        XCTAssertFalse(download.downloadListOptions.datePublished)

        // mocked list succeeded
        assertDisplay("🛑 Unknown or invalid file name : xxx.xip")
    }

}
