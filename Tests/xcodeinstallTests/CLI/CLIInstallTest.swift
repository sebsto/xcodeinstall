//
//  CLIInstallTest.swift
//  xcodeinstallTests
//
//  Created by Stormacq, Sebastien on 22/08/2022.
//

import XCTest
@testable import xcodeinstall

class CLIInstallTest: CLITest {
    
    func testInstall() async throws {
        
        // given
        let inst = try parse(MainCommand.Install.self, [
                            "install",
                            "--verbose",
                            "--name",
                            "test.xip"
        ])
        
        // when
        do {
            try await inst.run()
        } catch {
            // then
            XCTAssert(false, "unexpected exception : \(error)")
        }

        // test parsing of commandline arguments
        XCTAssert(inst.globalOptions.verbose)
        XCTAssertEqual(inst.name, "test.xip")
    }
    
    func testPromptForFile() {
        
        // given
        env.readLine = MockedReadLine(["0"])
        let xci = XCodeInstall()

        
        // when
        do {
            let result = try xci.promptForFile()
            
            // then
            XCTAssertTrue(result.lastPathComponent.hasSuffix("name.dmg"))

        } catch {
            // then
            XCTAssert(false, "unexpected exception : \(error)")
        }

    }

}
