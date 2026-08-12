//
//  ListCommand.swift
//  xcodeinstall
//
//  Created by Stormacq, Sebastien on 16/08/2022.
//

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

extension XCodeInstall {

    /// Fetches, parses and displays the list of available downloads.
    ///
    /// Errors are propagated untouched: they are rendered once by the CLI layer
    /// (see `ErrorPresenter`). This matters because `download` reuses this method
    /// through `askFile(...)`.
    func list(
        force: Bool,
        xCodeOnly: Bool,
        majorVersion: String,
        sortMostRecentFirst: Bool,
        datePublished: Bool
    ) async throws -> [DownloadList.Download] {

        let download = self.deps.downloader

        display("Loading list of available downloads...")

        let (list, source) = try await download.list(force: force)
        switch source {
        case .cache:
            display("Fetched from cache in \(self.deps.fileHandler.baseFilePath())", style: .info)
        case .network:
            if !force {
                display("No cache found, downloaded from Apple Developer Portal", style: .info)
            } else {
                display("Forced download from Apple Developer Portal", style: .info)
            }
        }
        display("Done", style: .success)

        let parser = DownloadListParser(
            fileHandler: self.deps.fileHandler,
            xCodeOnly: xCodeOnly,
            majorVersion: majorVersion,
            sortMostRecentFirst: sortMostRecentFirst
        )
        let parsedList = try parser.parse(list: list)

        // enrich the list to flag files already downloaded
        let enrichedList = await parser.enrich(list: parsedList)

        display("")
        display("Here is the list of available downloads:", style: .info)
        display("  Files marked with (*) are already downloaded in \(self.deps.fileHandler.baseFilePath()) ")
        display("")
        let string = parser.prettyPrint(list: enrichedList, withDate: datePublished)
        display(string)
        display("\(enrichedList.count) items")

        return enrichedList
    }
}
