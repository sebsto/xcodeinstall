//
//  NetworkAgentTestCase.swift
//  xcodeinstallTests
//
//  Created by Stormacq, Sebastien on 04/09/2022.
//

import XCTest
@testable import xcodeinstall

// common initilaisation code for all network agents
class NetworkAgentTestCase : AsyncTestCase {
    var subject : HTTPClient!
    var agent   : NetworkAgent!
    var secrets : FileSecretsHandler!
    var session : MockURLSession!
    var sema    : DispatchSemaphoreProtocol!
    var delegate : DownloadDelegate!
    var fileHandler : FileHandlerProtocol!

    override func asyncSetUpWithError() async throws {
        
        self.secrets = FileSecretsHandler.init()
        self.fileHandler = FileHandler()
        self.session = MockURLSession()
        self.sema    = MockDispatchSemaphore()
        self.subject = HTTPClient(session: session)
        self.agent   = NetworkAgent(client: subject, secrets: secrets, fileHandler: fileHandler)
        
        try await self.secrets.clearSecrets()
    }
    
    func getAppleSession() -> AppleSession {
        AppleSession(itcServiceKey:  AppleServiceKey(authServiceUrl: "url", authServiceKey: "key"),
                     xAppleIdSessionId: "x_apple_id_session_id",
                     scnt:                  "scnt")
    }
    
    func getAppleDownloader() -> AppleDownloader {
        let downloader = AppleDownloader(client: self.subject, secrets: self.secrets, fileHandler: self.fileHandler)
        downloader.sema = self.sema
        downloader.downloadDelegate = DownloadDelegate(semaphore: self.sema, fileHandler: self.fileHandler)
        return downloader
    }
    
    func getAppleAuthenticator() -> AppleAuthenticator {
        return AppleAuthenticator(client: subject, secrets: self.secrets, fileHandler: self.fileHandler)
    }
}
