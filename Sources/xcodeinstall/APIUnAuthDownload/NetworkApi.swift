//
//  NetworkApi.swift
//  
//
//  Created by Stormacq, Sebastien on 22/10/2022.
//

import Foundation
import CLIlib

protocol NetworkAPIProtocol {
    func data(for request: URLRequest, delegate: URLSessionTaskDelegate?) async throws -> (Data, URLResponse)
    func download(for request: URLRequest, delegate: URLSessionDownloadDelegate?) -> URLSessionDownloadTask
}

// allows to have default values in the protocol
// https://medium.com/@georgetsifrikas/swift-protocols-with-default-values-b7278d3eef22
extension NetworkAPIProtocol {
    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        return try await data(for: request, delegate: nil)
    }
    func download(for request: URLRequest) -> URLSessionDownloadTask {
        return download(for: request, delegate: nil)
    }
}
    
struct NetworkAPI : NetworkAPIProtocol {
    
    // MARK: retrieve data from URL
    func data(for request: URLRequest, delegate: URLSessionTaskDelegate? = nil) async throws -> (Data, URLResponse) {
        log.debug("Downloading data at \(request)")
        return try await URLSession.shared.data(for: request, delegate: delegate)
    }
    
    // MARK: download file from URL
    func download(for request: URLRequest, delegate: URLSessionDownloadDelegate? = nil) -> URLSessionDownloadTask {
        log.debug("Downloading file at \(request)")
        
        let session = URLSession(configuration: .default,
                             delegate: delegate,
                             delegateQueue: nil)
        return session.downloadTask(with: request)
    }

}
