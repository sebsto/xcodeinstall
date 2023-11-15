//
//  CliListTest.swift
//  xcodeinstallTests
//
//  Created by Stormacq, Sebastien on 22/08/2022.
//

import XCTest
@testable import xcodeinstall

class CLIListTest: CLITest {
    
    func testList() async throws {
        
        // given
        let list = try parse(MainCommand.List.self, [
                "list",
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
            //_ = try await xci.list(force: true, xCodeOnly: true, majorVersion: "14", sortMostRecentFirst: true, datePublished: true)
            try await list.run()
        } catch {
            // then
            XCTAssert(false, "unexpected exception : \(error)")
        }

        // test parsing of commandline arguments
        XCTAssert(list.globalOptions.verbose)
        XCTAssert(list.downloadListOptions.force)
        XCTAssert(list.downloadListOptions.onlyXcode)
        XCTAssert(list.downloadListOptions.xCodeVersion == "14")
        XCTAssert(list.downloadListOptions.mostRecentFirst)
        XCTAssert(list.downloadListOptions.datePublished)

        // mocked list succeeded
        assertDisplay("16 items")
    }
}
