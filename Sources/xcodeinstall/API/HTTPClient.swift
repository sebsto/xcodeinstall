//
//  HTTPClient.swift
//  xcodeinstall
//
//  Created by Stormacq, Sebastien on 21/07/2022.
//

import Foundation

/*
    This fil contains code to make our APICall testable.
 
    Inspired from https://masilotti.com/testing-nsurlsession-input/
 */

// make URLSession testable by abstracting its protocol
// it allows to use the real URLSession or a mock interchangably
protocol URLSessionProtocol {
    func data(for request: URLRequest, delegate: URLSessionTaskDelegate?) async throws -> (Data, URLResponse)
    func downloadTask(with request: URLRequest) throws -> URLSessionDownloadTaskProtocol
}

// make the real URLSession implements our new protocol to make the compiler happy
extension URLSession: URLSessionProtocol {
    func downloadTask(with request: URLRequest) throws -> URLSessionDownloadTaskProtocol {
        return downloadTask(with: request) as URLSessionDownloadTask
    }

}

// make URLSessionDownloadTask testable by abstracting its protocol
protocol URLSessionDownloadTaskProtocol {
    func resume()
}

// make the real URLSessionDownloadTask implemnet our protocol to keep the compiler happy
extension URLSessionDownloadTask: URLSessionDownloadTaskProtocol {}

// HTTP lient with dependency injection for URLSession
// our code will use this HTTPClient
// by default, it uses a real URLSession, at testing time, we inject our mock 
class HTTPClient: NSObject, URLSessionProtocol {

    private let session: URLSessionProtocol

    // by default, this class uses URLSession.shared
    // clients might inject other URLSession (for example to download)
    // at testing time, we inject a mock
    init(session: URLSessionProtocol) {
        self.session = session
    }

    func data(for request: URLRequest, delegate: URLSessionTaskDelegate? = nil) async throws -> (Data, URLResponse) {
        return try await session.data(for: request, delegate: delegate)
    }

    // function to download file. To monitor progress, the URLSession must be pass with non default values 
    func downloadTask(with request: URLRequest) throws -> URLSessionDownloadTaskProtocol {
        return try session.downloadTask(with: request)
    }

}
