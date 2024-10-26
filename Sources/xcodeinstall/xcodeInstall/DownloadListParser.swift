//
//  DownloadListParser.swift
//  xcodeinstall
//
//  Created by Stormacq, Sebastien on 24/07/2022.
//

import Foundation

struct DownloadListParser {

    var xCodeOnly: Bool
    var majorVersion: String
    var sortMostRecentFirst: Bool

    init(xCodeOnly: Bool = true, majorVersion: String = "13", sortMostRecentFirst: Bool = false) {
        self.xCodeOnly = xCodeOnly
        self.majorVersion = majorVersion
        self.sortMostRecentFirst = sortMostRecentFirst
    }

    func parse(list: DownloadList?) throws -> [DownloadList.Download] {

        guard let list = list?.downloads else {
            throw DownloadError.noDownloadsInDownloadList
        }

        // filter on items having Xcode in their name
        let listOfXcode = list.filter { download in
            if xCodeOnly {
                return download.name.starts(with: "Xcode \(majorVersion)")
            } else {
                return download.name.contains("Xcode \(majorVersion)")
            }
        }

        // sort by date (most recent last)
        let sortedList = listOfXcode.sorted { (downloadA, downloadB) in

            var dateA, dateB: String

            // select a non nil-date, either Published or Created.
            if let pubDateA = downloadA.datePublished,
               let pubDateB = downloadB.datePublished {
                dateA = pubDateA
                dateB = pubDateB
            } else {
                dateA = downloadA.dateCreated
                dateB = downloadB.dateCreated
            }

            // parse the string and return a date
            if let aAsDate = dateA.toDate(),
               let bAsDate = dateB.toDate() {
                return self.sortMostRecentFirst ? aAsDate > bAsDate : aAsDate < bAsDate
            } else {
                // I don't know what to do when we can not parse the date
                return false
            }
        }

        return sortedList
    }

    /// Enrich the list of available downloads.
    /// It adds a flag for each file in the list to indicate if the file is already downloaded and available in cache
    func enrich(list: [DownloadList.Download]) -> [DownloadList.Download] {

        let fileHandler = env.fileHandler

        return list.map { download in

            // swiftlint:disable identifier_name
            var d = download
            var file = download.files[0]

            let downloadFile: URL = fileHandler.downloadFileURL(file: file)
            let exists = fileHandler.fileExists(file: downloadFile, fileSize: file.fileSize)

            file.existInCache = exists
            d.files = [file]

            return d

        }
    }

    func prettyPrint(list: [DownloadList.Download], withDate: Bool = true) -> String {

        // var result = ""

        // map returns a [String] each containing a line to display
        let result: String = list.enumerated().map { (index, download) in
            var line: String = ""
            let file = download.files[0]

            // swiftlint:disable line_length
            line += "[\(String(format: "%02d", index))] \(download.name) (\(file.fileSize/1024/1024) Mb) \(file.existInCache ?? false ? "(*)" : "")"

            if withDate {
                if  let date = download.datePublished {
                    let das = date.toDate()
                    line += " (published on \(das?.formatted(date: .numeric, time: .omitted) ?? ""))"
                } else {
                    let das = download.dateCreated.toDate()
                    line += " (created on \(das?.formatted(date: .numeric, time: .omitted) ?? ""))"
                }
            }
            return line
        }
        // join all strings in [] with a \n
            .joined(separator: "\n")

        return result
    }
}

extension String {

    func toDate() -> Date? {

        let appleDownloadDateFormatter = DateFormatter()
        appleDownloadDateFormatter.locale = Locale(identifier: "en_US_POSIX")
        appleDownloadDateFormatter.dateFormat = "MM-dd-yy HH:mm"
        //        appleDownloadDateFormatter.timeZone = TimeZone(secondsFromGMT: 0) // assume GMT timezone

        return appleDownloadDateFormatter.date(from: self)
    }
}
