//
//  NetworkAgent.swift
//  xcodeinstall
//
//  Created by Stormacq, Sebastien on 21/07/2022.
//

import Foundation
import Logging

// callers can express expected HTTP Response code either as range, either as specific value
enum ExpectedResponseCode {
    case range(Range<Int>)
    case value(Int)

    func isValid(response: Int) -> Bool {
        switch self {
        case .range(let range):
                return range.contains(response)
        case .value(let value):
                return value == response
        }
    }
}

// provide common code for all network clients 
class NetworkAgent {

    enum HTTPVerb: String {
        case GET
        case POST
    }

    // our class wide logger
    let logger: Logger

    // HTTP client implements URLSession protocol
    // it is an absraction layer to allow to inject Mock URLSession when testing
    let httpClient: HTTPClient

    // A class to store / retrieve our secrets
    // at the moment I am using files to do so, will switch to AWS secrets manager
    // user should be able to select with an option
    let secretsHandler: SecretsHandler

    // A class to store / retrieve file, such as the download list cache
    let fileHandler: FileHandlerProtocol

    // some ID returned by Apple API to authenticate us
    var session = AppleSession()

    // allows to inject an HTTPClient (test injects a mock)
    init(client: HTTPClient, secrets: SecretsHandler, fileHandler: FileHandlerProtocol, logger: Logger) {
        self.httpClient     = client
        self.secretsHandler = secrets
        self.fileHandler    = fileHandler
        self.logger = logger
    }

    // to be shared between apiCall and download methods
    // prepare headers with correct cookies and X- value for Apple authentication
    func prepareAuthenticationHeaders() async -> [String: String] {

        var requestHeaders: [String: String]  = [ "Content-Type": "application/json",
                                                  "Accept": "application/json, text/javascript",
                                                  "X-Requested-With": "XMLHttpRequest",
                                                  "User-Agent": "curl/7.79.1"]

        // reload previous session if it exists
        let session = try? await secretsHandler.loadSession()
        if let session {

            // session is loaded
            self.session = session

        } else {
            logger.debug("⚠️ I could not load session (this is normal the first time you authenticate)")
        }

        // populate HTTP request with headers from session (either from self or the one just loaded)
        if let isk = self.session.itcServiceKey {
            requestHeaders["X-Apple-Widget-Key"] = isk.authServiceKey
        }
        if let aisi = self.session.xAppleIdSessionId {
            requestHeaders["X-Apple-ID-Session-Id"] = aisi
        }
        if let scnt = self.session.scnt {
            requestHeaders["scnt"] = scnt
        }

        // reload cookies if they exist
        let cookies = try? await secretsHandler.loadCookies()
        if let cookies {
            // cookies existed, let's add them to our HTTPHeaders
            requestHeaders.merge(HTTPCookie.requestHeaderFields(with: cookies)) { (current, _) in current }
        } else {
            // swiftlint:disable line_length
            logger.debug("⚠️ I could not load cookies (this is normal the first time you authenticate)")
        }

        return requestHeaders
    }

    // generic API CALL method
    // this is used by authentication API calls
    func apiCall(url: String,
                 method: HTTPVerb = .GET,
                 body: Data? = nil,
                 headers: [String: String] = [:],
                 validResponse: ExpectedResponseCode = .value(0)
    ) async throws -> (Data, HTTPURLResponse) {

        let request: URLRequest

        // let's add provided headers to our request (keeping new value in case of conflicts)
        var requestHeaders = await prepareAuthenticationHeaders()

        // add the headers our callers want in this request
        requestHeaders.merge(headers, uniquingKeysWith: { (_, new) in new })

        // and build the request
        request  = self.request(for: url,
                                method: method,
                                withBody: body,
                                withHeaders: requestHeaders)

        log(request: request, to: logger)

        // send request with that session
        let (data, response) = try await httpClient.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              validResponse.isValid(response: httpResponse.statusCode) else {
            logger.error("=== HTTP ERROR. Status code \((response as? HTTPURLResponse)!.statusCode) not in range \(validResponse) ===")
            logger.debug("URLResponse : \(response)")
            throw URLError(.badServerResponse)
        }

        log(response: httpResponse, data: data, error: nil, to: logger)

        return(data, httpResponse)
    }

    // generic Download CALL method
    // this is used by download API calls
    func downloadCall(url: String, requestHeaders: [String: String] = [:]) async throws -> (URLSessionDownloadTaskProtocol) {

        let request: URLRequest
        var headers = requestHeaders

        // reload cookies if they exist
        let cookies = try? await secretsHandler.loadCookies()
        if let cookies {
            // cookies existed, let's add them to our HTTPHeaders
            headers.merge(HTTPCookie.requestHeaderFields(with: cookies)) { (current, _) in current }
        } else {
            logger.debug("⚠️ I could not load cookies (this is normal the first time you authenticate)")
        }

        // build the request
        request  = self.request(for: url, withHeaders: headers)

        log(request: request, to: logger)

        // send request with download session
        // this is asynchronous, monitor progress through delegate
        return try  httpClient.downloadTask(with: request)
    }

    // prepare an URLRequest for a given url, method, body, and headers
    // https://softwareengineering.stackexchange.com/questions/100959/how-do-you-unit-test-private-methods
    // by OOP design it should be private.  Make it internal (default) for testing
    func request(for url: String,
                 method: HTTPVerb = .GET,
                 withBody body: Data? = nil,
                 withHeaders headers: [String: String]? = nil) -> URLRequest {

        // create the request
        let url = URL(string: url)!
        var request = URLRequest(url: url)

        // add HTTP verb
        request.httpMethod = method.rawValue

        // add body
        if let body {
            request.httpBody = body
        }

        // add headers
        if let headers {
            for (key, value) in headers {
                request.addValue(value, forHTTPHeaderField: key)
            }
        }

        return request
    }
}
