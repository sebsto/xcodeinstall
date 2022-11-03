//
//  NetworkApi.swift
//  
//
//  Created by Stormacq, Sebastien on 22/10/2022.
//

import Foundation

struct NetworkAPI {
    
    // MARK: retrieve data from URL
    
    // the mockable function as a property
    // actual implementation calls URLSession
    var data: (URLRequest, URLSessionTaskDelegate?) async throws -> (Data, URLResponse) = {
        return try await URLSession.shared.data(for: $0, delegate: $1)
    }
    
    // the actual function to be exposed to client of this class
    // this function calls the mockable function
    func data(for request: URLRequest, delegate: URLSessionTaskDelegate? = nil) async throws -> (Data, URLResponse) {
        try await data(request, delegate)
    }
    
    // MARK: download file from URL
    
    // the mockable function as a property
    // actual implementation calls URLSession
    var download: (URLRequest, URLSessionDownloadDelegate?) -> URLSessionDownloadTask = {
        let session = URLSession(configuration: .default,
                             delegate: $1,
                             delegateQueue: nil)
        return session.downloadTask(with: $0)
    }
    
    // the actual function to be exposed to client of this class
    // this function calls the mockable function
    func download(for request: URLRequest, delegate: URLSessionDownloadDelegate? = nil) -> URLSessionDownloadTask {
        return download(request, delegate)
    }

}
