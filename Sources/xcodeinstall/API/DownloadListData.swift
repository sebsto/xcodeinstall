//
//  DownloadData.swift
//  xcodeinstall
//
//  Created by Stormacq, Sebastien on 21/08/2022.
//

import Foundation

enum DownloadError: Error {
    case authenticationRequired
    case unknownError(errorCode: Int, errorMessage: String)
    case parsingError(error: Error)
    case noDownloadsInDownloadList
    case invalidFileSpec
    case invalidResponse
    case zeroOrMoreThanOneFileToDownload(count: Int)
    case unknownFile(file: String)
    case accountneedUpgrade(errorCode: Int, errorMessage: String)
}

struct DownloadList: Codable {

    struct DownloadCategory: Codable {
        let id: Int
        let name: String
        let sortOrder: Int
    }

    struct FileFormat: Codable {
        let fileExtension: String
        let description: String

        // real JSON name for fileExtension is extension
        // but this is a Swift reserved keyword
        // this allows to map internal name with JSON name

        enum CodingKeys: String, CodingKey { // swiftlint:disable:this nesting
            case fileExtension = "extension"
            case description
        }
    }

    struct File: Codable {
        let filename: String
        let displayName: String
        let remotePath: String
        let fileSize: Int
        let sortOrder: Int
        let dateCreated: String
        let dateModified: String
        let fileFormat: FileFormat
        var existInCache: Bool?
    }

    struct Download: Codable {
        let name: String
        let description: String
        let isReleased: Int
        let datePublished: String?
        let dateCreated: String
        let dateModified: String
        let categories: [DownloadCategory]
        var files: [File]
    }

    let creationTimestamp: String
    let resultCode: Int
    let resultString: String?
    let userString: String?
    let userLocale: String
    let protocolVersion: String
    let requestUrl: String
    let responseId: String
    let httpCode: Int?
    let httpResponseHeaders: [String: String]?
    let downloads: [Download]?

}
