//
//  CLIAuthTest.swift
//  xcodeinstallTests
//
//  Created by Stormacq, Sebastien on 22/08/2022.
//


import XCTest
import ArgumentParser
@testable import xcodeinstall

class CLIAUthTest: CLITest {
    
    func testSignout() async throws {
        
        // given
        var xci = xcodeinstall()
        xci.authenticator = MockAppleAuthentication()
        
        // when
        do {
            
            // verify no expectption is thrown
            let _ = try parse(MainCommand.Signout.self, ["signout"])
            
            //try await signoutCommand.run()
            try await xci.signout()
        } catch {
            // then
            XCTAssert(false, "unexpected exception : \(error)")
        }
        
        assertDisplay("✅ Signed out.")
    }

    func testSignoutWithError() async throws {
        
        // given
        let xci = xcodeinstall()
        
        // when
        do {
            try await xci.signout()
            XCTAssert(false)

        } catch XCodeInstallError.configurationError {

            // then
            XCTAssert(true)
        }
    }

    func testAuthenticate() async throws {
        
        // given
        let mockedReadline = MockedReadLine(["username", "password"])
        var xci = xcodeinstall(input: mockedReadline)
        xci.authenticator = MockAppleAuthentication()

        // when
        do {
            _ = try parse(MainCommand.Authenticate.self, ["authenticate"])
            try await xci.authenticate()
        } catch {
            // then
            XCTAssert(false, "unexpected exception : \(error)")
        }
        
        // mocked authentication succeeded
        assertDisplay("✅ Authenticated.")
        
        // two prompts have been proposed
        //print(mockedReadline.input)
        XCTAssert(mockedReadline.input.count == 0)

    }
    
    func testAuthenticateWithError() async throws {
        
        // given
        let xci = xcodeinstall()
        
        // when
        do {
            try await xci.authenticate()
            XCTAssert(false)
            
        } catch XCodeInstallError.configurationError {

            // then
            XCTAssert(true)
        }
    }
    
    func testAuthenticateInvalidUserOrpassword() async throws {
        
        // given
        let mockedReadline = MockedReadLine(["username", "password"])
        var xci = xcodeinstall(input: mockedReadline)
        xci.authenticator = MockAppleAuthentication(nextError: AuthenticationError.invalidUsernamePassword)

        // when
        do {
            _ = try parse(MainCommand.Authenticate.self, ["authenticate"])
            try await xci.authenticate()
        } catch {
            // then
            XCTAssert(false, "unexpected exception : \(error)")
        }
        
        assertDisplay("🛑 Invalid username or password.")

    }

//    func testAuthenticateMFATrustedDevice() async throws {
//
//        // given
//        let mockedReadline = MockedReadLine(["username", "password"])
//        let xci = xcodeinstall(input: mockedReadline,
//                               nextError: AuthenticationError.requires2FA,
//                               nextMFAError: AuthenticationError.requires2FATrustedDevice)
//
//        // when
//        do {
//            _ = try parse(MainCommand.Authenticate.self, ["authenticate"])
//            try await xci.authenticate()
//
//        } catch {
//            // then
//            XCTAssert(false, "unexpected exception : \(error)")
//        }
//
//        print((mockedDisplay as! MockedDisplay).string)
//        assertDisplayStartsWith("🔐 Two factors authentication is enabled, with 4 digit code and trusted devices.")
//
//    }
    
    func testAuthenticateMFATrustedPhoneNumber() async throws {
        
        // given
        let mockedReadline = MockedReadLine(["username", "password", "1234"])
//        let xci = xcodeinstall(input: mockedReadline,
//                               nextError: AuthenticationError.requires2FA,
//                               nextMFAError: AuthenticationError.requires2FATrustedPhoneNumber)
        var xci = xcodeinstall(input: mockedReadline)
        xci.authenticator = MockAppleAuthentication(nextError: AuthenticationError.requires2FA)

        // when
        do {
            _ = try parse(MainCommand.Authenticate.self, ["authenticate"])
            try await xci.authenticate()
            
        } catch {
            // then
            XCTAssert(false, "unexpected exception : \(error)")
        }
        
        // all inputs have been consumed
        XCTAssert(mockedReadline.input.count == 0)
        
        assertDisplay("✅ Authenticated with MFA.")

    }

}
