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

        let download = self.deps.downloader

        display("Loading list of available downloads...")

        do {
            let (list, source) = try await download.list(force: force)
            switch source {
            case .cache:
                display("Fetched from cache in \(self.deps.fileHandler.baseFilePath())")
            case .network:
                if !force {
                    display("No cache found, downloaded from Apple Developer Portal")
                } else {
                    display("Forced download from Apple Developer Portal")
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
            display("Files marked with (*) are already downloaded in \(self.deps.fileHandler.baseFilePath()) ")
            display("")
            let string = parser.prettyPrint(list: enrichedList, withDate: datePublished)
            display(string)
            display("\(enrichedList.count) items")

            return enrichedList

        } catch let error as DownloadError {
            switch error {
            case .authenticationRequired:
                display(
                    "Session expired, you need to re-authenticate.",
                    style: .error(nextSteps: ["xcodeinstall authenticate"])
                )
                throw error
            case .accountneedUpgrade(let code, let message):
                display("\(message) (Apple Portal error code : \(code))", style: .error())
                throw error
            case .needToAcceptTermsAndCondition:
                display(
                    """
                    This is a new Apple account, you need first to accept the developer terms of service.
                    Open a session at https://developer.apple.com/register/agree/
                    Read and accept the ToS and try again.
                    """,
                    style: .error()
                )
                throw error
            case .unknownError(let code, let message):
                display("\(message) (Unhandled download error : \(code))", style: .error())
                display(
                    "Please file an error report at https://github.com/sebsto/xcodeinstall/issues/new?assignees=&labels=&template=bug_report.md&title="
                )
                throw error
            default:
                display("Unknown download error : \(error)", style: .error())
                display(
                    "Please file an error report at https://github.com/sebsto/xcodeinstall/issues/new?assignees=&labels=&template=bug_report.md&title="
                )
                throw error
            }
        } catch let error as SecretsStorageAWSError {
            display("AWS Error: \(error.localizedDescription)", style: .error())
            throw error
        } catch {
            display("Unexpected error : \(error)", style: .error())
            throw error
        }

    }
}
