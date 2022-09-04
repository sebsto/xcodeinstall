//
//  NetworkAgentTestCase.swift
//  xcodeinstallTests
//
//  Created by Stormacq, Sebastien on 04/09/2022.
//

import XCTest
@testable import xcodeinstall

// common initilaisation code for all network agents
class NetworkAgentTestCase : XCTestCase {
    var subject : HTTPClient!
    var agent   : NetworkAgent!
    var log     : Log!
    var secrets : FileSecretsHandler!
    var session : MockURLSession!
    var sema    : DispatchSemaphoreProtocol!
    var delegate : DownloadDelegate!
    var fileHandler : FileHandlerProtocol!

    override func setUpWithError() throws {
        try super.setUpWithError()
        
        self.log     = Log(logLevel: .debug)
        self.secrets = FileSecretsHandler.init(logger: log.defaultLogger)
        self.fileHandler = FileHandler(logger: log.defaultLogger)
        self.session = MockURLSession()
        self.sema    = MockDispatchSemaphore()
        self.subject = HTTPClient(session: session)
        self.agent   = NetworkAgent(client: subject, secrets: secrets, fileHandler: fileHandler, logger: log.defaultLogger)
        
        self.secrets.clearSecrets()
    }
    
    override func tearDownWithError() throws {
//        self.secrets.restoreSecrets()
    }
    
    func getAppleSession() -> AppleSession {
        AppleSession(itcServiceKey:  AppleServiceKey(authServiceUrl: "url", authServiceKey: "key"),
                     xAppleIdSessionId: "x_apple_id_session_id",
                     scnt:                  "scnt")
    }
    
    func getAppleDownloader() -> AppleDownloader {
        let downloader = AppleDownloader(client: self.subject, secrets: self.secrets, fileHandler: self.fileHandler, logger: self.log.defaultLogger)
        downloader.sema = self.sema
        downloader.downloadDelegate = DownloadDelegate(semaphore: self.sema, fileHandler: self.fileHandler, logger: self.log.defaultLogger)
        return downloader
    }
    
    func getAppleAuthenticator() -> AppleAuthenticator {
        return AppleAuthenticator(client: subject, secrets: self.secrets, fileHandler: self.fileHandler, logger: self.log.defaultLogger)
    }
}
