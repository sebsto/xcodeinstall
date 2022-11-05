//
//  CLIInstallTest.swift
//  xcodeinstallTests
//
//  Created by Stormacq, Sebastien on 22/08/2022.
//

import XCTest
@testable import xcodeinstall

class CLIInstallTest: CLITest {
    
    func testInstallUnsupportedFile() async throws {
        
        // given
        let fileName = "test.xip"

        let installer = try parse(MainCommand.Install.self, [
                            "install",
                            "--verbose",
                            "--name",
                            fileName
        ])
        
        // when
        do {
            try await installer.run()
        } catch {
            // then
            XCTAssert(false, "unexpected exception : \(error)")
        }

        // test parsing of commandline arguments
        XCTAssert(installer.globalOptions.verbose)
        XCTAssertEqual(installer.name, "test.xip")
        
        assertDisplay("🛑 Unsupported installation type. (We support Xcode XIP files and Command Line Tools PKG)")
    }
    
    func testInstallFileDoesNotExist() async throws {
        
        // given
        let fileName = "Xcode 14.xip"
        (env.fileHandler as! MockedFileHandler).nextFileExist = false


        let installer = try parse(MainCommand.Install.self, [
                            "install",
                            "--verbose",
                            "--name",
                            fileName
        ])
        
        // when
        do {
            try await installer.run()
            
        } catch {
            // then
            XCTAssert(false, "Expected exception : \(error)")
        }

        // test parsing of commandline arguments
        XCTAssert(installer.globalOptions.verbose)
        XCTAssertEqual(installer.name, fileName)

        assertDisplay("⚠️ There is no downloaded file to be installed")
    }

    func testInstallXIP() async throws {
        
        // given
        let fileName = "Xcode 14.xip"
        (env.fileHandler as! MockedFileHandler).nextFileExist = true


        let installer = try parse(MainCommand.Install.self, [
                            "install",
                            "--verbose",
                            "--name",
                            fileName
        ])
        
        // when
        do {
            try await installer.run()
            
        } catch {
            // then
            XCTAssert(false, "Expected exception : \(error)")
        }

        // test parsing of commandline arguments
        XCTAssert(installer.globalOptions.verbose)
        XCTAssertEqual(installer.name, fileName)

        assertDisplayStartsWith("✅ /Users")
    }

    func testInstallDMG() async throws {
        
        // given
        let fileName = "Command Line Tools for Xcode 14.dmg"
        (env.fileHandler as! MockedFileHandler).nextFileExist = true


        let installer = try parse(MainCommand.Install.self, [
                            "install",
                            "--verbose",
                            "--name",
                            fileName
        ])
        
        // when
        do {
            try await installer.run()
            
        } catch {
            // then
            XCTAssert(false, "Expected exception : \(error)")
        }

        // test parsing of commandline arguments
        XCTAssert(installer.globalOptions.verbose)
        XCTAssertEqual(installer.name, fileName)

        assertDisplayStartsWith("✅ /Users")
    }

    
    func testPromptForFile() {

        // given
        (env.readLine as! MockedReadLine).input = ["0"]

        // when
        do {
            let result = try XCodeInstall().promptForFile()

            // then
            XCTAssertTrue(result.hasSuffix("name.dmg"))

        } catch {
            // then
            XCTAssert(false, "unexpected exception : \(error)")
        }

    }

}
