//
//  NetworkAgentTestCase.swift
//  xcodeinstallTests
//
//  Created by Stormacq, Sebastien on 04/09/2022.
//

@testable import xcodeinstall

// common initilaisation code for all network agents
@MainActor
class HTTPClientTestCase {

    var sessionData: MockedURLSession!
    var sessionDownload: MockedURLSession!
    var client: HTTPClient!
    var delegate: DownloadDelegate!

    let env = MockedEnvironment()

    init() async throws {

        self.sessionData = env.urlSessionData as? MockedURLSession
        self.sessionDownload = env.urlSessionDownload() as? MockedURLSession
        self.client = HTTPClient(env: env)

        try await env.secrets.clearSecrets()
    }

    func getAppleSession() -> AppleSession {
        AppleSession(
            itcServiceKey: AppleServiceKey(authServiceUrl: "url", authServiceKey: "key"),
            xAppleIdSessionId: "x_apple_id_session_id",
            scnt: "scnt",
            hashcash: "hashcash"
        )
    }

    func getAppleDownloader() -> AppleDownloader {
        AppleDownloader(env: env)
    }

    func getAppleAuthenticator() -> AppleAuthenticator {
        AppleAuthenticator(env: env)
    }
}
