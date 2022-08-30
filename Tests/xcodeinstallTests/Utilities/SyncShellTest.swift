//
//  ShellTest.swift
//  xcodeinstallTests
//
//  Created by Stormacq, Sebastien on 04/08/2022.
//

import XCTest
@testable import xcodeinstall

class SyncShellTest: XCTestCase {
    
    func testCommandSucceeds() throws {

        do {
            // given
            let command = "echo 'Seb'"

            // when
            let shell = SyncShell()
            let shellOutput = try shell.run(command)

            // then
            XCTAssertNotNil(shellOutput.out)
            XCTAssertNil(shellOutput.err)
            XCTAssert(shellOutput.code == 0)
            let out = try XCTUnwrap(shellOutput.out)
            XCTAssertTrue(out.contains("Seb\n"))

        } catch {
            XCTAssert(false, "Unexpected exception thown : \(error)")
        }
    }

    func testCommandReturnCommandNotFound() throws {

        do {
            // given
            let command = "xxxx"

            // when
            let shell = SyncShell()
            let shellOutput = try shell.run(command)

            // then
            XCTAssertNil(shellOutput.out)
            XCTAssertNotNil(shellOutput.err)
            XCTAssert(shellOutput.code == 127)
            XCTAssert(shellOutput.err!.contains("command not found: xxxx"))

        } catch {
            XCTAssert(false, "Unexpected exception thown : \(error)")
        }
    }

    func testCommandReturnsOne() throws {

        do {
            // given
            let command = "false"

            // when
            let shell = SyncShell()
            let shellOutput = try shell.run(command)

            // then
            XCTAssertNil(shellOutput.out)
            XCTAssertNil(shellOutput.err)
            XCTAssert(shellOutput.code == 1)

        } catch {
            XCTAssert(false, "Unexpected exception thown : \(error)")
        }
    }

}
