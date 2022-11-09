//
//  AppaleAvailableDownloads.swift
//
//  Created by Stormacq, Sebastien on 21/08/2022.
//

/**
 Read list created by the following command
 
 `xcodeinstall authenticate`
 `xcodeinstall list`-f
 `cat ~/.xcodeinstall/downloadList | jq -c .downloads > available-downloads.json`
 
 */
import Foundation

enum AppleAvailableDownloadsError: Error {
    case unknownError(errorCode: Int)
    case parsingError(error: Error)
    case invalidHTTPResponse
}

struct AvailableDownloadList {
    var list : [Download] // keep var to allow external filters
    var count : Int {
        return list.count
    }
    
    init(withData data:Data) throws {
        do {
            self.list = try JSONDecoder().decode([AvailableDownloadList.Download].self, from: data)
        } catch {
            throw AppleAvailableDownloadsError.parsingError(error: error)
        }
    }

    init(withFileURL url:URL) throws {
        let data = try Data(contentsOf: url)
        try self.init(withData: data)
    }

    /// check the entire list of downloads for files matching the given filename
    /// - Parameters
    ///     - fileName: the file name to check (without full path)
    /// - Returns
    ///     a File struct if a file matches, nil otherwise
    func find(fileName: String) -> Download.File? {

        guard self.list.count > 0 else {
            return nil
        }

        return _find(fileName: fileName, inList: self.list, comparison: { element in
            let download = element as Download
            return find(fileName: fileName, inDownload: download)
        })
    }

    // search the list of files ([File]) for an individual file match
    func find(fileName: String, inDownload download: Download) -> Download.File? {

        return _find(fileName: fileName, inList: download.files, comparison: { element in
            let file = element as Download.File
            return file.filename == fileName ? file : nil
        })

    }

    /// Check an entire list for files matching the given filename
    /// This generic function avoids repeating code in the two `find(...)` below
    /// - Parameters
    ///     - fileName: the file name to check (without full path)
    ///     - inList: either a [Download] or a [File]
    ///     - comparison: a function that receives either a `Download` either a `File`
    ///                and returns a `File` when there is a file name match, nil otherwise
    /// - Returns
    ///     a File struct if a file matches, nil otherwise

    private func _find<T: Sequence>(fileName: String, inList list: T, comparison: (T.Element) -> Download.File?) -> Download.File? {

        // first returns an array of File? with nil when filename does not match
        // or file otherwise.
        // for example : [nil, file, nil, nil]
        let result: [Download.File?] = list.compactMap { element -> Download.File? in
            return comparison(element)
        }
        // then remove all nil values
        .filter { file in
            return file != nil
        }

        // we should have 0 or 1 element
        if result.count > 0 {
            assert(result.count == 1)
            return result[0]
        } else {
            return nil
        }

    }

    // data structure
    struct Download: Codable {
        
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
        
        let name: String
        let description: String
        let isReleased: Int
        let datePublished: String?
        let dateCreated: String
        let dateModified: String
        let categories: [DownloadCategory]
        var files: [File]
        
    }
}
