//
//  HTTPClient.swift
//  xcodeinstall
//
//  Created by Stormacq, Sebastien on 21/07/2022.
//

import Foundation
import Logging

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/*
    This file contains code to make our APICall testable.

    Inspired from https://masilotti.com/testing-nsurlsession-input/
 */

// make URLSession testable by abstracting its protocol
// it allows to use the real URLSession or a mock interchangably
protocol URLSessionProtocol: Sendable {
    func data(
        for request: URLRequest,
        delegate: URLSessionTaskDelegate?
    ) async throws -> (
        Data, URLResponse
    )
}

// make the real URLSession implements our new protocol to make the compiler happy
extension URLSession: URLSessionProtocol {}

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

enum HTTPVerb: String {
    case GET
    case POST
    case PUT
}

// provide common code for all network clients
class HTTPClient {

    let secrets: SecretsHandlerProtocol
    let urlSession: URLSessionProtocol
    let log: Logger

    public init(secrets: SecretsHandlerProtocol, urlSession: URLSessionProtocol, log: Logger) {
        self.secrets = secrets
        self.urlSession = urlSession
        self.log = log
    }

    // some ID returned by Apple API to authenticate us
    var session = AppleSession()

    // how read-only requests are repeated when Apple's gateway fails
    var retryPolicy = TransientRetryPolicy()

    // to be shared between apiCall and download methods
    // prepare headers with correct cookies and X- value for Apple authentication
    func prepareAuthenticationHeaders() async -> [String: String] {

        var requestHeaders: [String: String] = [
            "Content-Type": "application/json",
            "Accept": "application/json, text/javascript",
            "X-Requested-With": "XMLHttpRequest",
            "User-Agent": "curl/7.79.1",
        ]

        // reload previous session if it exists
        let session = try? await self.secrets.loadSession()
        if let session {

            // session is loaded
            log.debug("Session data loaded", metadata: ["data": "\(session)"])
            self.session = session

        } else {
            log.debug("⚠️ I could not load session (this is normal the first time you authenticate)")
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
        let cookies = try? await self.secrets.loadCookies()
        if let cookies {
            // cookies existed, let's add them to our HTTPHeaders
            requestHeaders.merge(HTTPCookie.requestHeaderFields(with: cookies)) { (current, _) in current
            }
        } else {
            // swiftlint:disable line_length
            log.debug("⚠️ I could not load cookies (this is normal the first time you authenticate)")
        }

        return requestHeaders
    }

    // generic API CALL method
    // this is used by authentication API calls
    func apiCall(
        url: String,
        method: HTTPVerb = .GET,
        body: Data? = nil,
        headers: [String: String] = [:],
        validResponse: ExpectedResponseCode = .value(0),
        retryTransientErrors: Bool = false
    ) async throws -> (Data, HTTPURLResponse) {

        let request: URLRequest

        // let's add provided headers to our request (keeping new value in case of conflicts)
        var requestHeaders = await prepareAuthenticationHeaders()

        // add the headers our callers want in this request
        requestHeaders.merge(headers, uniquingKeysWith: { (_, new) in new })

        // and build the request
        request = self.request(
            for: url,
            method: method,
            withBody: body,
            withHeaders: requestHeaders
        )

        _log(request: request, to: log)

        // send request with that session.
        // Apple's sign in servers answer 502 / 503 / 504 for a share of otherwise
        // valid requests. Callers whose request is safe to repeat (read-only GETs)
        // opt in to a few retries; sign in POSTs never do.
        let (data, response) = try await retryPolicy.send(
            maxAttempts: retryTransientErrors ? retryPolicy.maxAttempts : 1,
            log: log
        ) {
            try await self.urlSession.data(for: request, delegate: nil)
        }
        guard let httpResponse = response as? HTTPURLResponse,
            validResponse.isValid(response: httpResponse.statusCode)
        else {
            log.error(
                "=== HTTP ERROR. Status code \((response as? HTTPURLResponse)!.statusCode) not in range \(validResponse) ==="
            )
            log.debug("URLResponse : \(response)")
            throw URLError(.badServerResponse)
        }

        _log(response: httpResponse, data: data, error: nil, to: log)

        return (data, httpResponse)
    }

    // prepare an URLRequest for a given url, method, body, and headers
    // https://softwareengineering.stackexchange.com/questions/100959/how-do-you-unit-test-private-methods
    internal func request(
        for url: String,
        method: HTTPVerb = .GET,
        withBody body: Data? = nil,
        withHeaders headers: [String: String]? = nil
    ) -> URLRequest {
        buildURLRequest(for: url, method: method, withBody: body, withHeaders: headers)
    }
}

// Shared URL request builder used by both HTTPClient and DownloadManager.
internal func buildURLRequest(
    for url: String,
    method: HTTPVerb = .GET,
    withBody body: Data? = nil,
    withHeaders headers: [String: String]? = nil
) -> URLRequest {

    // create the request
    guard let url = URL(string: url) else {
        fatalError("Invalid URL: \(url)")
    }
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

// Apple's sign in servers answer 502, 503 or 504 for a share of otherwise valid
// requests. This policy repeats a request while one of those comes back, waiting
// a little longer before each new attempt. Only requests that are safe to
// repeat (read-only GETs) should use it.
struct TransientRetryPolicy: Sendable {
    // total number of attempts, the first one included
    var maxAttempts = 5
    // pause before the second attempt; each later pause adds one more of these
    var retryDelay: Duration = .milliseconds(300)
    // gateway status codes worth another attempt
    var transientStatusCodes: Set<Int> = [502, 503, 504]

    // Run `request` up to `maxAttempts` times (this policy's own limit when the
    // caller passes none) and return the first answer that is not transient.
    func send(
        maxAttempts: Int? = nil,
        log: Logger,
        _ request: () async throws -> (Data, URLResponse)
    ) async throws -> (Data, URLResponse) {
        let limit = maxAttempts ?? self.maxAttempts
        var attempt = 1
        while true {
            let (data, response) = try await request()
            if let http = response as? HTTPURLResponse,
                transientStatusCodes.contains(http.statusCode),
                attempt < limit
            {
                log.debug("Transient HTTP \(http.statusCode), retrying (attempt \(attempt) of \(limit))")
                try await Task.sleep(for: retryDelay * attempt)
                attempt += 1
                continue
            }
            return (data, response)
        }
    }
}
