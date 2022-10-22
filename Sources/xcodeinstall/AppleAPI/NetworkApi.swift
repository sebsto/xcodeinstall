//
//  NetworkApi.swift
//  
//
//  Created by Stormacq, Sebastien on 22/10/2022.
//

import Foundation

struct NetworkAPI {
    
    var session = URLSession.shared
    
    // the mockable function as a property
    // actual implementation calls URLSession
    var data: (URLRequest, URLSessionTaskDelegate?) async throws -> (Data, URLResponse) = {
        return try await env.api.session.data(for: $0, delegate: $1)
    }
    
    // the actual function to be exposed to client of this class
    // this function calls the mockable function
    func data(for request: URLRequest, delegate: URLSessionTaskDelegate? = nil) async throws -> (Data, URLResponse) {
        try await data(request, delegate)
    }
}
