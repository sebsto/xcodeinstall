//
//  CLIAuthTest.swift
//  xcodeinstallTests
//
//  Created by Stormacq, Sebastien on 22/08/2022.
//

import ArgumentParser
import Foundation
import Testing

@testable import xcodeinstall

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

#if canImport(FoundationEssentials)
import FoundationEssentials
#endif

extension CLITests {

    @Test("Test Signout")
    func testSignout() async throws {

        // given
        let deps = env.toDeps(log: log)

        // when
        await #expect(throws: Never.self) {

            // verify no exception is thrown
            let signout = try parse(MainCommand.Signout.self, ["signout"])
            try await signout.run(with: deps)

        }

        assertDisplay("Signed out.")

        // verify shutdown was called on the secrets handler
        #expect((deps.secrets as? MockedSecretsHandler)?.shutdownCalled == true)
    }

    @Test("Test Authenticate")
    func testAuthenticate() async throws {

        // given
        let env = MockedEnvironment(readLine: MockedReadLine(["username", "password"]))
        env.secrets = MockedSecretsHandler(readLine: env.readLine)

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

        let deps = env.toDeps(log: log)

        // when
        await #expect(throws: Never.self) {
            let auth = try parse(MainCommand.Authenticate.self, ["authenticate"])
            try await auth.run(with: deps)
        }

        // mocked authentication succeeded
        assertDisplay(env: env, "Authenticated.")

        // two prompts have been proposed (username + password via delegate)
        #expect((env.readLine as! MockedReadLine).input.count == 0)

        // verify shutdown was called on the secrets handler
        #expect((deps.secrets as? MockedSecretsHandler)?.shutdownCalled == true)

    }

    @Test("Test Authenticate Invalid User Or Password")
    func testAuthenticateInvalidUserOrpassword() async throws {

        // given
        let env = MockedEnvironment(readLine: MockedReadLine(["username", "password"]))
        (env.authenticator as! MockedAppleAuthentication).nextError = AuthenticationError.invalidUsernamePassword

        let deps = env.toDeps(log: log)

        // when
        await #expect(throws: AuthenticationError.self) {
            _ = try parse(MainCommand.Authenticate.self, ["authenticate"])
            let xci = XCodeInstall(log: log, deps: deps)
            try await xci.authenticate(with: AuthenticationMethod.withSRP(false))
        }

        assertDisplay(env: env, "Invalid username or password.")

    }

    func getAppleSession() -> AppleSession {
        AppleSession(
            itcServiceKey: AppleServiceKey(authServiceUrl: "url", authServiceKey: "key"),
            xAppleIdSessionId: "x_apple_id_session_id",
            scnt: "scnt"
        )
    }

    @Test("Test Authenticate MFA Trusted Device via Delegate")
    func testAuthenticateMFATrustedDevice() async throws {

        // given — username, password, and MFA code
        let env = MockedEnvironment(readLine: MockedReadLine(["username", "password", "123456"]))
        let authenticator = (env.authenticator as! MockedAppleAuthentication)
        authenticator.nextError = AuthenticationError.requires2FA
        // no MFA error — the mock will call delegate.requestMFACode and succeed

        let deps = env.toDeps(log: log)

        // when
        await #expect(throws: Never.self) {
            let xci = XCodeInstall(log: log, deps: deps)
            try await xci.authenticate(with: AuthenticationMethod.withSRP(false))
        }

        // all inputs have been consumed (username, password, MFA code)
        #expect((env.readLine as! MockedReadLine).input.count == 0)

        assertDisplay(env: env, "Authenticated.")
    }

    @Test("Test Authenticate MFA Trusted Phone Number Error")
    func testAuthenticateMFATrustedPhoneNumber() async throws {

        // given — username, password (MFA will fail with trustedPhoneNumber error)
        let env = MockedEnvironment(readLine: MockedReadLine(["username", "password"]))
        let authenticator = (env.authenticator as! MockedAppleAuthentication)
        authenticator.nextError = AuthenticationError.requires2FA
        authenticator.nextMFAError = AuthenticationError.requires2FATrustedPhoneNumber

        let deps = env.toDeps(log: log)

        // when
        await #expect(throws: AuthenticationError.self) {
            let xci = XCodeInstall(log: log, deps: deps)
            try await xci.authenticate(with: AuthenticationMethod.withSRP(false))
        }

        // username and password consumed by delegate.requestCredentials()
        #expect((env.readLine as! MockedReadLine).input.count == 0)

        assertDisplayStartsWith(
            env: env,
            "Two factors authentication is enabled"
        )
    }

    @Test("Test Signout SecretsStorageAWSError")
    func testSignoutSecretsStorageAWSError() async throws {

        // given
        let env = MockedEnvironment()
        env.secrets = MockedSecretsHandler(readLine: env.readLine)
        (env.authenticator as! MockedAppleAuthentication).nextSignoutError =
            SecretsStorageAWSError.invalidRegion(region: "bad-region")

        let deps = env.toDeps(log: log)
        let xci = XCodeInstall(log: log, deps: deps)

        // when
        await #expect(throws: SecretsStorageAWSError.self) {
            try await xci.signout()
        }

        // then — verify the AWS Error message was displayed
        assertDisplayStartsWith(env: env, "AWS Error:")
    }

    @Test("Test Signout Generic Error")
    func testSignoutGenericError() async throws {

        // given
        let env = MockedEnvironment()
        env.secrets = MockedSecretsHandler(readLine: env.readLine)
        (env.authenticator as! MockedAppleAuthentication).nextSignoutError = MockError.genericTestError

        let deps = env.toDeps(log: log)
        let xci = XCodeInstall(log: log, deps: deps)

        // when
        await #expect(throws: MockError.self) {
            try await xci.signout()
        }

        // then — verify the Unexpected error message was displayed
        assertDisplayStartsWith(env: env, "Unexpected error")
    }

    // MARK: - Authenticate Error Path Tests

    @Test("Test Authenticate Service Unavailable")
    func testAuthenticateServiceUnavailable() async throws {
        // given
        let env = MockedEnvironment(readLine: MockedReadLine(["username", "password"]))
        (env.authenticator as! MockedAppleAuthentication).nextError = AuthenticationError.serviceUnavailable
        let deps = env.toDeps(log: log)

        // when
        await #expect(throws: AuthenticationError.self) {
            let xci = XCodeInstall(log: log, deps: deps)
            try await xci.authenticate(with: AuthenticationMethod.withSRP(false))
        }

        // then
        assertDisplayContains(env: env, "Requested authentication method is not available")
    }

    @Test("Test Authenticate Unable To Retrieve Service Key")
    func testAuthenticateUnableToRetrieveServiceKey() async throws {
        // given
        let env = MockedEnvironment(readLine: MockedReadLine(["username", "password"]))
        (env.authenticator as! MockedAppleAuthentication).nextError = AuthenticationError.unableToRetrieveAppleServiceKey(nil)
        let deps = env.toDeps(log: log)

        // when
        await #expect(throws: AuthenticationError.self) {
            let xci = XCodeInstall(log: log, deps: deps)
            try await xci.authenticate(with: AuthenticationMethod.withSRP(false))
        }

        // then
        assertDisplayContains(env: env, "Can not connect to Apple Developer Portal")
    }

    @Test("Test Authenticate Not Implemented")
    func testAuthenticateNotImplemented() async throws {
        // given
        let env = MockedEnvironment(readLine: MockedReadLine(["username", "password"]))
        (env.authenticator as! MockedAppleAuthentication).nextError = AuthenticationError.notImplemented(featureName: "SomeFeature")
        let deps = env.toDeps(log: log)

        // when
        await #expect(throws: AuthenticationError.self) {
            let xci = XCodeInstall(log: log, deps: deps)
            try await xci.authenticate(with: AuthenticationMethod.withSRP(false))
        }

        // then
        assertDisplayContains(env: env, "SomeFeature is not yet implemented")
    }

    @Test("Test Authenticate Secrets Storage AWS Error")
    func testAuthenticateSecretsStorageAWSError() async throws {
        // given
        let env = MockedEnvironment(readLine: MockedReadLine(["username", "password"]))
        (env.authenticator as! MockedAppleAuthentication).nextGenericError = SecretsStorageAWSError.invalidRegion(region: "bad-region")
        let deps = env.toDeps(log: log)

        // when
        await #expect(throws: SecretsStorageAWSError.self) {
            let xci = XCodeInstall(log: log, deps: deps)
            try await xci.authenticate(with: AuthenticationMethod.withSRP(false))
        }

        // then
        assertDisplayContains(env: env, "AWS Error")
    }

    @Test("Test Authenticate Unexpected Error")
    func testAuthenticateUnexpectedError() async throws {
        // given
        let env = MockedEnvironment(readLine: MockedReadLine(["username", "password"]))
        (env.authenticator as! MockedAppleAuthentication).nextGenericError = MockError.genericTestError
        let deps = env.toDeps(log: log)

        // when
        await #expect(throws: MockError.self) {
            let xci = XCodeInstall(log: log, deps: deps)
            try await xci.authenticate(with: AuthenticationMethod.withSRP(false))
        }

        // then
        assertDisplayContains(env: env, "Unexpected Error")
    }

    @Test("Test Authenticate With Username Password Method")
    func testAuthenticateWithUsernamePasswordMethod() async throws {
        // given
        let env = MockedEnvironment(readLine: MockedReadLine(["username", "password"]))
        (env.authenticator as! MockedAppleAuthentication).nextError = nil
        let deps = env.toDeps(log: log)

        // when
        await #expect(throws: Never.self) {
            let xci = XCodeInstall(log: log, deps: deps)
            try await xci.authenticate(with: AuthenticationMethod.usernamePassword)
        }

        // then
        assertDisplayContains(env: env, "Authenticating with username and password (likely to fail)")
    }

    // MARK: - CLIAuthenticationDelegate Tests

    @Test("Test Request MFA Code Multiple Options Trusted Device")
    func testRequestMFACodeMultipleOptionsTrustedDevice() async throws {
        // given
        let env = MockedEnvironment(readLine: MockedReadLine(["1", "123456"]))
        let deps = env.toDeps(log: log)
        let delegate = CLIAuthenticationDelegate(deps: deps)

        let testPhone = MFAType.PhoneNumber(numberWithDialCode: "+1 (555) 123-4567", pushMode: nil, obfuscatedNumber: "*******4567", lastTwoDigits: "67", id: 1)
        let options: [MFAOption] = [
            .trustedDevice(codeLength: 6),
            .sms(phoneNumber: testPhone, codeLength: 6)
        ]

        // when
        let (option, code) = try await delegate.requestMFACode(options: options)

        // then
        if case .trustedDevice(let codeLength) = option {
            #expect(codeLength == 6)
            #expect(code == "123456")
        } else {
            Issue.record("Expected .trustedDevice option")
        }
    }

    @Test("Test Request MFA Code Multiple Options Choose SMS")
    func testRequestMFACodeMultipleOptionsChooseSMS() async throws {
        // given
        let env = MockedEnvironment(readLine: MockedReadLine(["2"]))
        let deps = env.toDeps(log: log)
        let delegate = CLIAuthenticationDelegate(deps: deps)

        let testPhone = MFAType.PhoneNumber(numberWithDialCode: "+1 (555) 123-4567", pushMode: nil, obfuscatedNumber: "*******4567", lastTwoDigits: "67", id: 1)
        let options: [MFAOption] = [
            .trustedDevice(codeLength: 6),
            .sms(phoneNumber: testPhone, codeLength: 6)
        ]

        // when
        let (option, code) = try await delegate.requestMFACode(options: options)

        // then
        if case .sms = option {
            #expect(code == "")  // SMS returns empty code
        } else {
            Issue.record("Expected .sms option")
        }
    }

    @Test("Test Request MFA Code Invalid Choice")
    func testRequestMFACodeInvalidChoice() async throws {
        // given
        let env = MockedEnvironment(readLine: MockedReadLine(["abc"]))
        let deps = env.toDeps(log: log)
        let delegate = CLIAuthenticationDelegate(deps: deps)

        let testPhone = MFAType.PhoneNumber(numberWithDialCode: "+1 (555) 123-4567", pushMode: nil, obfuscatedNumber: "*******4567", lastTwoDigits: "67", id: 1)
        let options: [MFAOption] = [
            .trustedDevice(codeLength: 6),
            .sms(phoneNumber: testPhone, codeLength: 6)
        ]

        // when/then
        await #expect(throws: CLIError.self) {
            _ = try await delegate.requestMFACode(options: options)
        }
    }

    @Test("Test Request MFA Code Single SMS Option")
    func testRequestMFACodeSingleSMSOption() async throws {
        // given
        let env = MockedEnvironment(readLine: MockedReadLine(["654321"]))
        let deps = env.toDeps(log: log)
        let delegate = CLIAuthenticationDelegate(deps: deps)

        let testPhone = MFAType.PhoneNumber(numberWithDialCode: "+1 (555) 123-4567", pushMode: nil, obfuscatedNumber: "*******4567", lastTwoDigits: "67", id: 1)
        let options: [MFAOption] = [.sms(phoneNumber: testPhone, codeLength: 6)]

        // when
        let (option, code) = try await delegate.requestMFACode(options: options)

        // then
        if case .sms = option {
            #expect(code == "654321")
        } else {
            Issue.record("Expected .sms option")
        }
    }

    @Test("Test Request MFA Code Empty Options")
    func testRequestMFACodeEmptyOptions() async throws {
        // given
        let env = MockedEnvironment(readLine: MockedReadLine([]))
        let deps = env.toDeps(log: log)
        let delegate = CLIAuthenticationDelegate(deps: deps)

        let options: [MFAOption] = []

        // when/then
        await #expect(throws: CLIError.self) {
            _ = try await delegate.requestMFACode(options: options)
        }
    }

    @Test("Test Request MFA Code Nil ReadLine")
    func testRequestMFACodeNilReadLine() async throws {
        // given
        let env = MockedEnvironment(readLine: NilMockedReadLine())
        let deps = env.toDeps(log: log)
        let delegate = CLIAuthenticationDelegate(deps: deps)

        let options: [MFAOption] = [.trustedDevice(codeLength: 6)]

        // when/then
        await #expect(throws: CLIError.self) {
            _ = try await delegate.requestMFACode(options: options)
        }
    }

}
