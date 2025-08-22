//
//  CLIAuthTest.swift
//  xcodeinstallTests
//
//  Created by Stormacq, Sebastien on 22/08/2022.
//

import ArgumentParser
import Testing

@testable import xcodeinstall

import Foundation

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

#if canImport(FoundationEssentials)
import FoundationEssentials
#endif

@MainActor
extension CLITests {

    func testSignout() async throws {

        // given

        // when
        await #expect(throws: Never.self) {

            // verify no exception is thrown
            let signout = try parse(MainCommand.Signout.self, ["signout"])
            try await signout.run(with: env)

        }

        assertDisplay("✅ Signed out.")
    }

    func testAuthenticate() async throws {

        // given
        let env = MockedEnvironment(readLine: MockedReadLine(["username", "password"]))

        let authenticator = (env.authenticator as! MockedAppleAuthentication)
        authenticator.nextError = nil

        let session: MockedURLSession = env.urlSessionData as! MockedURLSession
        let headers = ["X-Apple-ID-Session-Id": "dummySessionID", "scnt": "dummySCNT"]
        session.nextResponse = HTTPURLResponse(
            url: URL(string: "https://dummy")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: headers
        )

        // when
        await #expect(throws: Never.self) {
            let auth = try parse(MainCommand.Authenticate.self, ["authenticate"])
            try await auth.run(with: env)
        }

        // mocked authentication succeeded
        assertDisplay("✅ Authenticated.")

        // two prompts have been proposed
        // print((env.readLine as! MockedReadLine).input)
        #expect((env.readLine as! MockedReadLine).input.count == 0)

    }

    func testAuthenticateInvalidUserOrpassword() async throws {

        // given
        let env = MockedEnvironment(readLine: MockedReadLine(["username", "password"]))
        (env.authenticator as! MockedAppleAuthentication).nextError = AuthenticationError.invalidUsernamePassword

        // when
        await #expect(throws: Never.self) {
            _ = try parse(MainCommand.Authenticate.self, ["authenticate"])
            let xci = XCodeInstall(log: log, env: env)
            try await xci.authenticate(with: AuthenticationMethod.withSRP(false))
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
        AppleSession(
            itcServiceKey: AppleServiceKey(authServiceUrl: "url", authServiceKey: "key"),
            xAppleIdSessionId: "x_apple_id_session_id",
            scnt: "scnt"
        )
    }
    func testAuthenticateMFATrustedPhoneNumber() async throws {

        // given
        let env = MockedEnvironment(readLine: MockedReadLine(["username", "password", "1234"]))
        let authenticator = (env.authenticator as! MockedAppleAuthentication)
        authenticator.nextError = AuthenticationError.requires2FA
        (self.secretsHandler as! MockedSecretsHandler).nextError = SecretsStorageAWSError.invalidOperation
        let session: MockedURLSession = env.urlSessionData as! MockedURLSession
        session.nextData = getMFATypeOK().data(using: .utf8)
        let headers = ["X-Apple-ID-Session-Id": "dummySessionID", "scnt": "dummySCNT"]
        session.nextResponse = HTTPURLResponse(
            url: URL(string: "https://dummy")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: headers
        )

        // when
        let error = await #expect(throws: AuthenticationError.self) {
            let xci = XCodeInstall(log: log, env: env)
            _ = try parse(MainCommand.Authenticate.self, ["authenticate"])
            try await xci.authenticate(with: AuthenticationMethod.withSRP(false))

        }
        if case let .unexpectedHTTPReturnCode(code) = error {
            #expect(code == 500, "Unexpected HTTP return code : \(code)")
        } else {
            Issue.record("unexpected exception : \(String(describing: error))")
        }

        // all inputs have been consumed
        #expect((env.readLine as! MockedReadLine).input.count == 0)

        assertDisplay("✅ Authenticated with MFA.")

    }

    private func getMFATypeOK() -> String {
        """
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
