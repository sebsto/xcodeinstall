//
//  CLIInstallTest.swift
//  xcodeinstallTests
//
//  Created by Stormacq, Sebastien on 22/08/2022.
//

import Testing

@testable import xcodeinstall

@MainActor
extension CLITests {

    @Test("Test Install Command")
    func testInstall() async throws {

        // given
        let inst = try parse(
            MainCommand.Install.self,
            [
                "install",
                "--verbose",
                "--name",
                "test.xip",
            ]
        )

        // when
        await #expect(throws: Never.self) { try await inst.run() }

        // test parsing of commandline arguments
        #expect(inst.globalOptions.verbose)
        #expect(inst.name == "test.xip")

        // verify if progressbar define() was called
        if let progress = env.progressBar as? MockedProgressBar {
            #expect(progress.defineCalled())
        } else {
            Issue.record("Error in test implementation, the env.progressBar must be a MockedProgressBar")
        }
    }

    @Test("Test Install Command with no name")
    func testPromptForFile() {

        // given
        let env : MockedEnvironment = MockedEnvironment(readLine: MockedReadLine(["0"]))
        let xci = XCodeInstall(env: env)

        // when
        do {
            let result = try xci.promptForFile()

            // then
            #expect(result.lastPathComponent.hasSuffix("name.dmg"))

        } catch {
            // then
            Issue.record("unexpected exception : \(error)")
        }

    }

}
