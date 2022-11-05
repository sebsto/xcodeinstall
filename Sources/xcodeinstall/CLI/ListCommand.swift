//
//  ListCommand.swift
//  xcodeinstall
//
//  Created by Stormacq, Sebastien on 16/08/2022.
//

import Foundation

extension XCodeInstall {
    

    func list(majorVersion: String,
              sortMostRecentFirst: Bool,
              datePublished: Bool) async throws -> [AvailableDownloadList.Download] {

        display("Loading list of available downloads...")

        do {
            let fileHandler = env.fileHandler
            let downloader = env.downloader
            
            let list = try await downloader.listAvailableDownloads()
            display("✅ Done")

            let parser = DownloadListParser(xCodeOnly: false,
                                            majorVersion: majorVersion,
                                            sortMostRecentFirst: sortMostRecentFirst)
            let parsedList = try parser.parse(downloadList: list)

            // enrich the list to flag files already downloaded
            let enrichedList = parser.enrich(list: parsedList)

            display("")
            display("👉 Here is the list of available downloads:")
            display("Files marked with (*) are already downloaded in \(fileHandler.baseFilePath()) ")
            display("")
            let string = parser.prettyPrint(list: enrichedList, withDate: datePublished)
            display(string)
            display("\(enrichedList.count) items")

            return enrichedList

        } catch {
            display("🛑 Unexpected error : \(error)")
            throw error
        }

    }
}
