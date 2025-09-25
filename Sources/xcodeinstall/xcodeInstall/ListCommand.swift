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

    func list(
        force: Bool,
        xCodeOnly: Bool,
        majorVersion: String,
        sortMostRecentFirst: Bool,
        datePublished: Bool
    ) async throws -> [DownloadList.Download] {

        let download = self.env.downloader

        display("Loading list of available downloads ", terminator: "")
        display(
            "\(force ? "forced download from Apple Developer Portal" : "fetched from cache in \(self.env.fileHandler.baseFilePath())")"
        )  // swiftlint:disable:this line_length

        do {
            let list = try await download.list(force: force)
            display("✅ Done")

            let parser = DownloadListParser(
                env: self.env,
                xCodeOnly: xCodeOnly,
                majorVersion: majorVersion,
                sortMostRecentFirst: sortMostRecentFirst
            )
            let parsedList = try parser.parse(list: list)

            // enrich the list to flag files already downloaded
            let enrichedList = await parser.enrich(list: parsedList)

            display("")
            display("👉 Here is the list of available downloads:")
            display("Files marked with (*) are already downloaded in \(self.env.fileHandler.baseFilePath()) ")
            display("")
            let string = parser.prettyPrint(list: enrichedList, withDate: datePublished)
            display(string)
            display("\(enrichedList.count) items")

            return enrichedList

        } catch let error as DownloadError {
            switch error {
            case .authenticationRequired:
                display("🛑 Session expired, you neeed to re-authenticate.")
                display("You can authenticate with the command: xcodeinstall authenticate")
                throw error
            case .accountneedUpgrade(let code, let message):
                display("🛑 \(message) (Apple Portal error code : \(code))")
                throw error
            case .needToAcceptTermsAndCondition:
                display(
                    """
                    🛑 This is a new Apple account, you need first to accept the developer terms of service.
                    Open a session at https://developer.apple.com/register/agree/
                    Read and accept the ToS and try again.
                    """
                )
                throw error
            case .unknownError(let code, let message):
                display("🛑 \(message) (Unhandled download error : \(code))")
                display(
                    "Please file an error report at https://github.com/sebsto/xcodeinstall/issues/new?assignees=&labels=&template=bug_report.md&title="
                )
                throw error
            default:
                display("🛑 Unknown download error : \(error)")
                display(
                    "Please file an error report at https://github.com/sebsto/xcodeinstall/issues/new?assignees=&labels=&template=bug_report.md&title="
                )
                throw error
            }
        } catch {
            display("🛑 Unexpected error : \(error)")
            display(
                "Please file an error repor at https://github.com/sebsto/xcodeinstall/issues/new?assignees=&labels=&template=bug_report.md&title="
            )
            throw error
        }

    }
}
