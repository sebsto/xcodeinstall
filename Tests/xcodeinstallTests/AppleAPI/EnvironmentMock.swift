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
    static var mock = NetworkAPI(
        data: { request , delegate in
            let data = Data()
            let headers = ["Set-Cookie" : "ADCDownloadAuth=AuthCookieValue;Version=1;Comment=;Domain=apple.com;Path=/;Max-Age=108000;HttpOnly;Expires=Sat, 22 Oct 2032 04:54:51 GMT"]
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: headers)!
            return (data, response as URLResponse)
        }
    )
}
