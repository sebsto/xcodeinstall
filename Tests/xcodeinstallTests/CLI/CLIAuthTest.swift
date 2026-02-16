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
    }

    @Test("Test Authenticate")
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

    }

    @Test("Test Authenticate Invalid User Or Password")
    func testAuthenticateInvalidUserOrpassword() async throws {

        // given
        let env = MockedEnvironment(readLine: MockedReadLine(["username", "password"]))
        (env.authenticator as! MockedAppleAuthentication).nextError = AuthenticationError.invalidUsernamePassword

        let deps = env.toDeps(log: log)

        // when
        await #expect(throws: Never.self) {
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
        await #expect(throws: Never.self) {
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

}
