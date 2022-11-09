//
//  File.swift
//  
//
//  Created by Stormacq, Sebastien on 05/11/2022.
//

import Foundation
@testable import xcodeinstall

class MockedNetworkAPI : NetworkAPIProtocol {
    var nextData : Data = Data()
    var nextHeader : [String:String] = [:]
    var nextStatusCode : Int = 200
    var nextDownloadTask : URLSessionDownloadTask? = nil
    var nextError : Error? = nil
    
    func data(for request: URLRequest, delegate: URLSessionTaskDelegate?) async throws -> (Data, URLResponse) {
        let response = HTTPURLResponse(url: request.url!, statusCode: nextStatusCode, httpVersion: "HTTP/1.1", headerFields: nextHeader)!
        return (nextData, response as URLResponse)
    }
    
    func download(for request: URLRequest, delegate: URLSessionDownloadDelegate?) -> URLSessionDownloadTask {
        return URLSession.shared.downloadTask(with: request)
    }
}

class MockedApplePackageDownloader : ApplePackageDownloaderProtocol {
    func listAvailableDownloads() async throws -> AvailableDownloadList {
        return try loadAvailableDownloadFromTestFile()
    }
    
    func download(_ package: Package, with delegate: AppleDownloadDelegate) async throws -> URL {
        return URL(fileURLWithPath: "/tmp/dummy")
    }
    
}
