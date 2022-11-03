//
//  File.swift
//  
//
//  Created by Stormacq, Sebastien on 22/10/2022.
//

import Foundation
@testable import xcodeinstall

extension Environment {
    
    static var mock = Environment(
        api: NetworkAPI.mock
    )
}

extension NetworkAPI {
    static var nextData : Data = Data()
    static var nextHeader : [String:String] = [:]
    static var nextStatusCode : Int = 200
    static var nextDownloadTask : URLSessionDownloadTask? = nil
    static var nextError : Error? = nil

    static var mock = NetworkAPI(
        
        // mocked implementation of URLSession
        data: { request , delegate in
            
            let response = HTTPURLResponse(url: request.url!, statusCode: nextStatusCode, httpVersion: "HTTP/1.1", headerFields: nextHeader)!
            return (nextData, response as URLResponse)
        },
        
        download: { request, delegate in
            
            return URLSession.shared.downloadTask(with: request)
        }
    )
}
