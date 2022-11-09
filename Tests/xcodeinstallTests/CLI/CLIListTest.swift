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
                "--xcode-version",
                "14",
                "--most-recent-first",
                "--date-published",
        ])
        
        // when
        do {
            try await list.run() 
        } catch {
            // then
            XCTAssert(false, "unexpected exception : \(error)")
        }

        // test parsing of commandline arguments
        XCTAssert(list.globalOptions.verbose)
        XCTAssert(list.downloadListOptions.xCodeVersion == "14")
        XCTAssert(list.downloadListOptions.mostRecentFirst)
        XCTAssert(list.downloadListOptions.datePublished)

        // mocked list succeeded
        assertDisplay("20 items")
    }
}
