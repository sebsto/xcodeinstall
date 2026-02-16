//
//  MockedNetworkClasses.swift
//  xcodeinstallTests
//
//  Created by Stormacq, Sebastien on 21/08/2022.
//

import Foundation
import Logging

@testable import xcodeinstall

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

// mocked URLSession to be used during test
@MainActor
final class MockedURLSession: URLSessionProtocol {

    let log = Logger(label: "MockedURLSession")
    private(set) var lastURL: URL?
    private(set) var lastRequest: URLRequest?

    var nextData: Data?
    var nextError: Error?
    var nextResponse: URLResponse?

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

}

@MainActor
final class MockedAppleAuthentication: AppleAuthenticatorProtocol {

    var nextError: AuthenticationError?
    var nextMFAError: AuthenticationError?
    var nextGenericError: (any Error)?
    var session: AppleSession?

    func authenticate(
        with method: AuthenticationMethod,
        delegate: AuthenticationDelegate
    ) async throws {
        // Get credentials from delegate (consumes readline inputs)
        let (_, _) = try await delegate.requestCredentials()

        // Allow tests to throw arbitrary (non-AuthenticationError) errors
        if let genericError = nextGenericError {
            throw genericError
        }

        if let error = nextError {
            if error == .requires2FA {
                // Simulate the authenticator driving MFA internally
                if let mfaError = nextMFAError {
                    throw mfaError
                }
                let options: [MFAOption] = [.trustedDevice(codeLength: 6)]
                let (chosen, _) = try await delegate.requestMFACode(options: options)

                // If SMS was chosen, simulate sending SMS and asking for code again
                if case .sms(let phone, let codeLength) = chosen {
                    let (_, _) = try await delegate.requestMFACode(options: [
                        .sms(phoneNumber: phone, codeLength: codeLength)
                    ])
                }
                // MFA succeeded (mock doesn't actually verify)
                return
            }
            throw error
        }
    }

    func startAuthentication(
        with authenticationMethod: AuthenticationMethod,
        username: String,
        password: String
    ) async throws {

        if let nextError {
            throw nextError
        }

    }
    var nextSignoutError: Error?
    func signout() async throws {
        if let nextSignoutError { throw nextSignoutError }
    }
    func handleTwoFactorAuthentication() async throws -> Int {
        if let nextMFAError {
            throw nextMFAError
        }
        return 6
    }
    func twoFactorAuthentication(pin: String) async throws {}
}

@MainActor
final class MockedAppleDownloader: AppleDownloaderProtocol {
    var nextListResult: DownloadList?
    var nextListError: Error?
    var nextListSource: ListSource = .cache

    func list(force: Bool) async throws -> (DownloadList, ListSource) {
        if let error = nextListError { throw error }
        if let list = nextListResult { return (list, nextListSource) }
        // Default: load from test data
        let listData = try loadTestData(file: .downloadList)
        let list = try JSONDecoder().decode(DownloadList.self, from: listData)
        return (list, nextListSource)
    }

    var nextDownloadError: Error?
    func download(file: DownloadList.File) async throws -> AsyncThrowingStream<DownloadProgress, Error> {
        if let nextDownloadError { throw nextDownloadError }
        let dm = MockDownloadManager()
        return dm.download(from: URL(string: file.filename)!)

    }
}
