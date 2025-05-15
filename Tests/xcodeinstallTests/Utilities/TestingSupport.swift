//
//  TestingSupport.swift
//  xcodeinstallTests
//
//  Created for swift-testing migration
//

import Foundation
import Testing

@testable import xcodeinstall

/// A utility for running async code in tests
func runAsyncAndWait<T>(_ asyncBlock: @escaping () async throws -> T) throws -> T {
    let semaphore = DispatchSemaphore(value: 0)
    var result: Result<T, Error> = .failure(NSError(domain: "Async operation did not complete", code: -1))
    
    Task {
        do {
            let value = try await asyncBlock()
            result = .success(value)
        } catch {
            result = .failure(error)
        }
        semaphore.signal()
    }
    
    semaphore.wait()
    
    switch result {
    case .success(let value):
        return value
    case .failure(let error):
        throw error
    }
}

/// Base test suite for HTTP client tests
struct HTTPClientTestSuite {
    var sessionData: MockedURLSession!
    var sessionDownload: MockedURLSession!
    var client: HTTPClient!
    var delegate: DownloadDelegate!
    
    mutating func setUp() async throws {
        env = Environment.mock
        
        self.sessionData = env.urlSessionData as? MockedURLSession
        self.sessionDownload = env.urlSessionDownload as? MockedURLSession
        self.client = HTTPClient()
        
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
        AppleDownloader()
    }
    
    func getAppleAuthenticator() -> AppleAuthenticator {
        AppleAuthenticator()
    }
}