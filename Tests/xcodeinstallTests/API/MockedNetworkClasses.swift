//
//  MockedNetworkClasses.swift
//  xcodeinstallTests
//
//  Created by Stormacq, Sebastien on 21/08/2022.
//

import CLIlib
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

@MainActor
final class MockedAppleDownloader: AppleDownloaderProtocol {
    var urlSession: URLSessionProtocol?
    var secrets: SecretsHandlerProtocol?

    func list(force: Bool) async throws -> DownloadList {
        if !force {
            let listData = try loadTestData(file: .downloadList)
            let list: DownloadList = try JSONDecoder().decode(DownloadList.self, from: listData)
            return list
        }

        // For forced list, check mocked URLSession data
        guard let mockedSession = urlSession as? MockedURLSession,
            let data = mockedSession.nextData,
            let response = mockedSession.nextResponse as? HTTPURLResponse
        else {
            throw MockError.invalidMockData
        }

        // Check response status code first
        guard response.statusCode == 200 else {
            throw DownloadError.invalidResponse
        }

        // Check for cookies (except for specific test cases)
        let hasCookies = response.value(forHTTPHeaderField: "Set-Cookie") != nil

        // Try to decode the response first to check if it's valid JSON
        let downloadList: DownloadList
        do {
            downloadList = try JSONDecoder().decode(DownloadList.self, from: data)
        } catch {
            // If JSON parsing fails, throw parsing error
            throw DownloadError.parsingError(error: nil)
        }

        // Now check for cookies after successful JSON parsing
        if !hasCookies && downloadList.resultCode == 0 {
            throw DownloadError.invalidResponse
        }

        // Check result code for various error conditions
        switch downloadList.resultCode {
        case 0:
            return downloadList
        case 1100:
            throw DownloadError.authenticationRequired
        case 2170:
            throw DownloadError.accountneedUpgrade(
                errorCode: downloadList.resultCode,
                errorMessage: downloadList.userString ?? "Your developer account needs to be updated"
            )
        default:
            throw DownloadError.unknownError(
                errorCode: downloadList.resultCode,
                errorMessage: downloadList.userString ?? "Unknown error"
            )
        }
    }

    func download(file: DownloadList.File) async throws -> AsyncThrowingStream<DownloadProgress, Error> {
        let dm = MockDownloadManager()
        return dm.download(from: URL(string: file.filename)!)

    }
}
