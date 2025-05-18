//
//  CliListTest.swift
//  xcodeinstallTests
//
//  Created by Stormacq, Sebastien on 22/08/2022.
//

import Testing

@testable import xcodeinstall

@MainActor
extension CLITests {

    @Test("Test List Command")
    func testList() async throws {

        // given
        let list = try parse(
            MainCommand.List.self,
            [
                "list",
                "--verbose",
                "--force",
                "--only-xcode",
                "--xcode-version",
                "14",
                "--most-recent-first",
                "--date-published",
            ]
        )

        // when

        await #expect(throws: Never.self) { try await list.run(with: env) }

        // test parsing of commandline arguments
        #expect(list.globalOptions.verbose)
        #expect(list.downloadListOptions.force)
        #expect(list.downloadListOptions.onlyXcode)
        #expect(list.downloadListOptions.xCodeVersion == "14")
        #expect(list.downloadListOptions.mostRecentFirst)
        #expect(list.downloadListOptions.datePublished)

        // mocked list succeeded
        assertDisplay("16 items")
    }
}
