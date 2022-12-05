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
        
        // when
        do {
            
            // verify no exception is thrown
            let signout = try parse(MainCommand.Signout.self, ["signout"])
            try await signout.run()
            
        } catch {
            // then
            XCTAssert(false, "unexpected exception : \(error)")
        }
        
        assertDisplay("✅ Signed out.")
    }

    func testAuthenticate() async throws {
        
        // given
        env.readLine = MockedReadLine(["username", "password"])
        
        let authenticator = (env.authenticator as! MockedAppleAuthentication)
        authenticator.nextError = nil

        let session : MockedURLSession = env.urlSessionData as! MockedURLSession
        let headers = [ "X-Apple-ID-Session-Id" : "dummySessionID", "scnt" : "dummySCNT"]
        session.nextResponse = HTTPURLResponse(url: URL(string: "https://dummy")!, statusCode: 200, httpVersion: nil, headerFields: headers)

        // when
        do {
            let auth = try parse(MainCommand.Authenticate.self, ["authenticate"])
            try await auth.run()
        } catch {
            // then
            XCTAssert(false, "unexpected exception : \(error)")
        }
        
        // mocked authentication succeeded
        assertDisplay("✅ Authenticated.")
        
        // two prompts have been proposed
        print((env.readLine as! MockedReadLine).input)
        XCTAssert((env.readLine as! MockedReadLine).input.count == 0)

    }
    
    func testAuthenticateInvalidUserOrpassword() async throws {
        
        // given
        env.readLine = MockedReadLine(["username", "password"])
        let xci = XCodeInstall()
        (env.authenticator as! MockedAppleAuthentication).nextError = AuthenticationError.invalidUsernamePassword

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
    
    func getAppleSession() -> AppleSession {
        AppleSession(itcServiceKey:  AppleServiceKey(authServiceUrl: "url", authServiceKey: "key"),
                     xAppleIdSessionId: "x_apple_id_session_id",
                     scnt:                  "scnt")
    }
    func testAuthenticateMFATrustedPhoneNumber() async throws {
        
        // given
        env.readLine = MockedReadLine(["username", "password", "1234"])
        let authenticator = (env.authenticator as! MockedAppleAuthentication)
        authenticator.nextError = AuthenticationError.requires2FA
        (self.secretsHandler as! MockedSecretHandler).nextError = AWSSecretsHandlerError.invalidOperation
        let session : MockedURLSession = env.urlSessionData as! MockedURLSession
        session.nextData = getMFATypeOK().data(using: .utf8)
        let headers = [ "X-Apple-ID-Session-Id" : "dummySessionID", "scnt" : "dummySCNT"]
        session.nextResponse = HTTPURLResponse(url: URL(string: "https://dummy")!, statusCode: 200, httpVersion: nil, headerFields: headers)

        // when
        do {
            let xci = XCodeInstall()
            _ = try parse(MainCommand.Authenticate.self, ["authenticate"])
            try await xci.authenticate()
            
        } catch {
            // then
            XCTAssert(false, "unexpected exception : \(error)")
        }
        
        // all inputs have been consumed
        XCTAssert((env.readLine as! MockedReadLine).input.count == 0)
        
        assertDisplay("✅ Authenticated with MFA.")

    }
    
    private func getMFATypeOK() -> String {
            return """
 {
   "trustedPhoneNumbers" : [ {
     "numberWithDialCode" : "+33 •• •• •• •• 88",
     "pushMode" : "sms",
     "obfuscatedNumber" : "•• •• •• •• 88",
     "lastTwoDigits" : "88",
     "id" : 2
   } ],
   "securityCode" : {
     "length" : 6,
     "tooManyCodesSent" : false,
     "tooManyCodesValidated" : false,
     "securityCodeLocked" : false,
     "securityCodeCooldown" : false
   },
   "authenticationType" : "hsa2",
   "recoveryUrl" : "https://iforgot.apple.com/phone/add?prs_account_nm=sebsto%40mac.com&autoSubmitAccount=true&appId=142",
   "cantUsePhoneNumberUrl" : "https://iforgot.apple.com/iforgot/phone/add?context=cantuse&prs_account_nm=sebsto%40mac.com&autoSubmitAccount=true&appId=142",
   "recoveryWebUrl" : "https://iforgot.apple.com/password/verify/appleid?prs_account_nm=sebsto%40mac.com&autoSubmitAccount=true&appId=142",
   "repairPhoneNumberUrl" : "https://gsa.apple.com/appleid/account/manage/repair/verify/phone",
   "repairPhoneNumberWebUrl" : "https://appleid.apple.com/widget/account/repair?#!repair",
   "aboutTwoFactorAuthenticationUrl" : "https://support.apple.com/kb/HT204921",
   "twoFactorVerificationSupportUrl" : "https://support.apple.com/HT208072",
   "hasRecoveryKey" : true,
   "supportsRecoveryKey" : false,
   "autoVerified" : false,
   "showAutoVerificationUI" : false,
   "supportsCustodianRecovery" : false,
   "hideSendSMSCodeOption" : false,
   "supervisedChangePasswordFlow" : false,
   "supportsRecovery" : true,
   "trustedPhoneNumber" : {
     "numberWithDialCode" : "+33 •• •• •• •• 88",
     "pushMode" : "sms",
     "obfuscatedNumber" : "•• •• •• •• 88",
     "lastTwoDigits" : "88",
     "id" : 2
   },
   "hsa2Account" : true,
   "restrictedAccount" : false,
   "managedAccount" : false
 }
"""
    }


}
