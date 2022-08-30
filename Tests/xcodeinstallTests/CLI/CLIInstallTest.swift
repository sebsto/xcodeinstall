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
        var xci = xcodeinstall()
        xci.installer = MockedInstaller()

        let inst = try parse(MainCommand.Install.self, [
                            "install",
                            "--verbose",
                            "--name",
                            "test.xip"
        ])
        
        // when
        do {
            try await xci.install(file: "test.xip")
        } catch {
            // then
            XCTAssert(false, "unexpected exception : \(error)")
        }

        // test parsing of commandline arguments
        XCTAssert(inst.globalOptions.verbose)
        XCTAssertEqual(inst.name, "test.xip")
    }
}
