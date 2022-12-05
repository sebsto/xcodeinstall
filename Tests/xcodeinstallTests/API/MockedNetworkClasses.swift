//
//  MockedNetworkClasses.swift
//  xcodeinstallTests
//
//  Created by Stormacq, Sebastien on 21/08/2022.
//

import Foundation
import CLIlib
@testable import xcodeinstall


// mocked URLSessionDownloadTask
class MockedURLSessionDownloadTask: URLSessionDownloadTaskProtocol {
    
    var wasResumeCalled = false
    
    func resume() {
        self.wasResumeCalled = true
    }
}

// mocked URLSession to be used during test
class MockedURLSession: URLSessionProtocol {
    
    private (set) var lastURL: URL?
    private (set) var lastRequest: URLRequest?
    
    var nextData: Data?
    var nextError: Error?
    var nextResponse: URLResponse?
    
    var nextURLSessionDownloadTask: URLSessionDownloadTaskProtocol?
    
    func data(for request: URLRequest, delegate: URLSessionTaskDelegate? = nil) async throws -> (Data, URLResponse) {
        
        guard let data = nextData,
              let response = nextResponse else {
            throw MockError.invalidMockData
        }
        
        lastURL     = request.url
        lastRequest = request
        
        if nextError != nil {
            throw nextError!
        }
        
        return (data, response)
    }
    
    func downloadTask(with request: URLRequest) throws -> URLSessionDownloadTaskProtocol {
        
        guard let downloadTask = nextURLSessionDownloadTask else {
            throw MockError.invalidMockData
        }
        
        lastURL     = request.url
        lastRequest = request
        
        if nextError != nil {
            throw nextError!
        }
        
        return downloadTask
    }
}

class MockedAppleAuthentication: AppleAuthenticatorProtocol {
    
    var nextError : AuthenticationError?
    var nextMFAError : AuthenticationError?
    var session : AppleSession?
    
    func startAuthentication(username: String, password: String) async throws {
        
        if let nextError {
            throw nextError
        }
            
    }
    func signout() async throws {}
    func handleTwoFactorAuthentication() async throws -> Int {
        if let nextMFAError {
            throw nextMFAError
        }
        return 6
    }
    func twoFactorAuthentication(pin: String) async throws {}
}

struct MockedAppleDownloader : AppleDownloaderProtocol {
    var sema: DispatchSemaphoreProtocol = MockedDispatchSemaphore()
    var downloadDelegate: DownloadDelegate?

    func list(force: Bool) async throws -> DownloadList {
        let listData = try loadTestData(file: .downloadList)
        let list: DownloadList = try JSONDecoder().decode(DownloadList.self, from: listData)
        
        guard let _ = list.downloads else {
            throw MockError.invalidMockData
        }
        return list
    }
    func download(file: DownloadList.File) async throws -> URLSessionDownloadTaskProtocol? {
        // should create a file with matching size
        let dlt = MockedURLSessionDownloadTask()
        return dlt
    }
}

class MockedDispatchSemaphore: DispatchSemaphoreProtocol {
    var wasWaitCalled = false
    var wasSignalCalled = false

    func wait() { wasWaitCalled = true }
    func signal() -> Int {
        wasSignalCalled = true
        return 0
    }
}
