//
//  URLLogger.swift
//  xcodeinstall
//
//  Created by Stormacq, Sebastien on 18/07/2022.
//

import CLIlib
import Foundation
import Logging

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

// Using Swift's modern regex syntax
func filterPassword(_ input: String) -> String {
    let regex = /("password":").*?("[\,\}])/
    return input.replacing(regex) { match in
        "\(match.1)*****\(match.2)"
    }
}

func log(request: URLRequest, to logger: Logger) {

    log.debug("\n - - - - - - - - - - OUTGOING - - - - - - - - - - \n")
    defer { log.debug("\n - - - - - - - - - -  END - - - - - - - - - - \n") }
    let urlAsString = request.url?.absoluteString ?? ""
    let urlComponents = URLComponents(string: urlAsString)
    let method = request.httpMethod != nil ? "\(request.httpMethod ?? "")" : ""
    let path = "\(urlComponents?.path ?? "")"
    let query = "\(urlComponents?.query ?? "")"
    let host = "\(urlComponents?.host ?? "")"
    var output = """
        \(urlAsString) \n\n
        \(method) \(path)?\(query) HTTP/1.1 \n
        HOST: \(host)\n
        """

    for (key, value) in request.allHTTPHeaderFields ?? [:] {
        output += "\(key): \(value)\n"

    }

    if let body = request.httpBody {
        output += "\n \(String(data: body, encoding: .utf8) ?? "")"
    }
    logger.debug("\(filterPassword(output))")
}

func log(response: HTTPURLResponse?, data: Data?, error: Error?, to logger: Logger) {

    logger.debug("\n - - - - - - - - - - INCOMMING - - - - - - - - - - \n")
    defer { logger.debug("\n - - - - - - - - - -  END - - - - - - - - - - \n") }
    let urlString = response?.url?.absoluteString
    let components = NSURLComponents(string: urlString ?? "")
    let path = "\(components?.path ?? "")"
    let query = "\(components?.query ?? "")"
    var output = ""
    if let urlString {
        output += "\(urlString)"
        output += "\n\n"
    }
    if let statusCode = response?.statusCode {
        output += "HTTP \(statusCode) \(path)?\(query)\n"
    }
    if let host = components?.host {
        output += "Host: \(host)\n"
    }
    for (key, value) in response?.allHeaderFields ?? [:] {
        output += "\(key): \(value)\n"
    }
    if let data {
        output += "\n\(String(data: data, encoding: .utf8) ?? "")\n"
    }
    if error != nil {
        output += "\nError: \(error!.localizedDescription)\n"
    }
    logger.debug("\(output)")
}
