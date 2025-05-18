//
//  MockedNetworkClasses.swift
//  xcodeinstallTests
//
//  Created by Stormacq, Sebastien on 21/08/2022.
//

import CLIlib
import Foundation

@testable import xcodeinstall

// import Synchronization

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

// mocked URLSessionDownloadTask
@MainActor
final class MockedURLSessionDownloadTask: URLSessionDownloadTaskProtocol {

    // private let _wasResumeCalled: Mutex<Bool> = .init(false)
    // var wasResumeCalled: Bool {
    //     return self._wasResumeCalled.withLock { $0 }
    // }

    // func resume() {
    //     self._wasResumeCalled.withLock { $0 = true }
    // }

    var wasResumeCalled: Bool = false
    func resume() {
        wasResumeCalled = true
    }
}

// mocked URLSession to be used during test
@MainActor
final class MockedURLSession: URLSessionProtocol {

    private(set) var lastURL: URL?
    private(set) var lastRequest: URLRequest?

    var nextData: Data?
    var nextError: Error?
    var nextResponse: URLResponse?

    var nextURLSessionDownloadTask: URLSessionDownloadTaskProtocol?

    func data(for request: URLRequest, delegate: URLSessionTaskDelegate? = nil) async throws -> (Data, URLResponse) {

        guard let data = nextData,
            let response = nextResponse
        else {
            throw MockError.invalidMockData
        }

        lastURL = request.url
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

        lastURL = request.url
        lastRequest = request

        if nextError != nil {
            throw nextError!
        }

        return downloadTask
    }

    var delegate: DownloadDelegate?
    func downloadDelegate() -> DownloadDelegate? {
        if delegate == nil {
            delegate = DownloadDelegate(
                env: MockedEnvironment(),
                semaphore: MockedDispatchSemaphore()
            )
        }
        return delegate
    }
}

@MainActor
final class MockedAppleAuthentication: AppleAuthenticatorProtocol {

    var nextError: AuthenticationError?
    var nextMFAError: AuthenticationError?
    var session: AppleSession?

    func startAuthentication(
        with authenticationMethod: AuthenticationMethod,
        username: String,
        password: String
    ) async throws {

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

struct MockedAppleDownloader: AppleDownloaderProtocol {
    var sema: DispatchSemaphoreProtocol = MockedDispatchSemaphore()
    var downloadDelegate: DownloadDelegate?

    func delegate() -> DownloadDelegate {
        self.downloadDelegate!
    }
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

@MainActor
final class MockedDispatchSemaphore: DispatchSemaphoreProtocol {
    var _wasWaitCalled = false
    var _wasSignalCalled = false

    // reset flag when called
    func wasWaitCalled() -> Bool {
        let wwc = _wasWaitCalled
        _wasWaitCalled = false
        return wwc
    }

    // reset flag when called
    func wasSignalCalled() -> Bool {
        let wsc = _wasSignalCalled
        _wasSignalCalled = false
        return wsc
    }

    func wait() { _wasWaitCalled = true }
    func signal() -> Int {
        _wasSignalCalled = true
        return 0
    }
}
