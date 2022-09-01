//
//  HTTPClientTest.swift
//  xcodeinstallTests
//
//  Created by Stormacq, Sebastien on 21/07/2022.
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
        
        self.secrets.clearSecrets(preserve: true)
    }
    
    override func tearDownWithError() throws {
        self.secrets.restoreSecrets()
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

class HTTPClientTest: NetworkAgentTestCase {
    
    func testRequest() async throws {
        
        let url      = "https://test.com/path"
        let username = "username"
        let password = "password"
        
        let headers  = [ "header1" : "value1",
                         "header2" : "value2"]
        let body = try JSONEncoder().encode(User(accountName: username, password: password))
        let request  = agent.request(for: url,
                                     method: .POST,
                                     withBody: body,
                                     withHeaders: headers)
        
        // test URL
        XCTAssertEqual(request.url?.debugDescription, url)
        
        // test method
        XCTAssertEqual(request.httpMethod, "POST")
        
        // test body
        XCTAssertNotNil(request.httpBody)
        let user = try JSONDecoder().decode(User.self, from: request.httpBody!)
        XCTAssertEqual(user.accountName, username)
        XCTAssertEqual(user.password, password)
        
        // test headers
        XCTAssertNotNil(request.allHTTPHeaderFields)
        XCTAssert(request.allHTTPHeaderFields!.count == 2)
        XCTAssertEqual(request.allHTTPHeaderFields!["header1"], "value1")
        XCTAssertEqual(request.allHTTPHeaderFields!["header2"], "value2")
        
    }
    
    // not a super usefull test, but it helped me to understand the dynamic of Mocks
    func testDataRequestsTheURL() async throws {
        
        // given
        let url = "http://dummy"
        
        self.session.nextData     = Data()
        self.session.nextResponse = URLResponse()
        
        // when
        let request = agent.request(for: url)
        _ = try await subject.data(for: request, delegate: nil)
        
        // then
        XCTAssertEqual(self.session.lastURL?.debugDescription, url)
        
    }
    
}
