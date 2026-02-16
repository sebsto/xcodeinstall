//
//  CliListTest.swift
//  xcodeinstallTests
//
//  Created by Stormacq, Sebastien on 22/08/2022.
//

import Testing

@testable import xcodeinstall

extension CLITests {

    @Test("Test List Command")
    func testList() async throws {

        // given
        let list = try parse(
            MainCommand.List.self,
            [
                "list",
                "--verbose",
                "--only-xcode",
                "--xcode-version",
                "14",
                "--most-recent-first",
                "--date-published",
            ]
        )

        let deps = env.toDeps(log: log)

        // when

        await #expect(throws: Never.self) { try await list.run(with: deps) }

        // test parsing of commandline arguments
        #expect(list.globalOptions.verbose)
        #expect(list.downloadListOptions.onlyXcode)
        #expect(list.downloadListOptions.xCodeVersion == "14")
        #expect(list.downloadListOptions.mostRecentFirst)
        #expect(list.downloadListOptions.datePublished)

        // mocked list succeeded
        assertDisplay("16 items")

        // verify shutdown was called on the secrets handler
        #expect((deps.secrets as? MockedSecretsHandler)?.shutdownCalled == true)
    }
}
