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
    
    var session : MockedURLSession!
    var agent   : HTTPClient!
    var delegate : DownloadDelegate!

    override func asyncSetUpWithError() async throws {
        
        env = Environment.mock
        
        self.session = (env.urlSession as! MockedURLSession)
        self.agent   = HTTPClient()
        
        try await env.secrets.clearSecrets()
    }
    
    func getAppleSession() -> AppleSession {
        AppleSession(itcServiceKey:  AppleServiceKey(authServiceUrl: "url", authServiceKey: "key"),
                     xAppleIdSessionId: "x_apple_id_session_id",
                     scnt:                  "scnt")
    }
    
    func getAppleDownloader() -> AppleDownloader {

        let downloader = AppleDownloader()
        downloader.downloadDelegate = DownloadDelegate(semaphore: MockedDispatchSemaphore())
        return downloader
    }
    
    func getAppleAuthenticator() -> AppleAuthenticator {
        return AppleAuthenticator()
    }
}
