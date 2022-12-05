//
//  NetworkAgentTestCase.swift
//  xcodeinstallTests
//
//  Created by Stormacq, Sebastien on 04/09/2022.
//

import XCTest
@testable import xcodeinstall

// common initilaisation code for all network agents
class HTTPClientTestCase : AsyncTestCase {
    
    var sessionData     : MockedURLSession!
    var sessionDownload : MockedURLSession!
    var client          : HTTPClient!
    var delegate        : DownloadDelegate!

    override func asyncSetUpWithError() async throws {
        
        env = Environment.mock
        
        self.sessionData     = env.urlSessionData as? MockedURLSession
        self.sessionDownload = env.urlSessionDownload as? MockedURLSession
        self.client           = HTTPClient()
        
        try await env.secrets.clearSecrets()
    }
    
    func getAppleSession() -> AppleSession {
        AppleSession(itcServiceKey:  AppleServiceKey(authServiceUrl: "url", authServiceKey: "key"),
                     xAppleIdSessionId: "x_apple_id_session_id",
                     scnt:                  "scnt")
    }
    
    func getAppleDownloader() -> AppleDownloader {
        return AppleDownloader()
    }
    
    func getAppleAuthenticator() -> AppleAuthenticator {
        return AppleAuthenticator()
    }
}
