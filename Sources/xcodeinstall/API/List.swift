//
//  List.swift
//  xcodeinstall
//
//  Created by Stormacq, Sebastien on 21/08/2022.
//

import CLIlib
import Foundation

extension AppleDownloader {

    // load the list of available downloads
    // when force is true, dowload from Apple even when there is a cache on disk
    // https://developer.apple.com
    // POST /services-account/QH65B2/downloadws/listDownloads.action
    //
    func list(force: Bool) async throws -> DownloadList {

        var downloadList: DownloadList?

        if !force {
            // load the list from file if we have it
            downloadList = try? self.env.fileHandler.loadDownloadList()
        }

        if downloadList == nil {
            let url =
                "https://developer.apple.com/services-account/QH65B2/downloadws/listDownloads.action"
            let (data, response) = try await apiCall(
                url: url,
                method: .POST,
                validResponse: .range(200..<400)
            )

            guard response.statusCode == 200 else {
                log.error("🛑 Download List response is not 200, something is incorrect")
                log.debug("URLResponse = \(response)")
                throw DownloadError.invalidResponse
            }

            do {
                downloadList = try JSONDecoder().decode(DownloadList.self, from: data)
            } catch {
                throw DownloadError.parsingError(error: error)
            }

            if downloadList!.resultCode == 0 {

                // grab authentication cookie for later download
                if let cookies = response.value(forHTTPHeaderField: "Set-Cookie") {
                    // save the new cookies we received (ADCDownloadAuth)
                    _ = try await self.env.secrets!.saveCookies(cookies)
                } else {
                    // swiftlint:disable line_length
                    log.error(
                        "🛑 Download List response does not contain authentication cookie, something is incorrect"
                    )
                    log.debug("URLResponse = \(response)")
                    throw DownloadError.invalidResponse
                }

                // success, save the list for reuse
                _ = try self.env.fileHandler.saveDownloadList(list: downloadList!)

            } else {

                switch downloadList!.resultCode {
                case 1100:  // authentication expired
                    throw DownloadError.authenticationRequired
                case 2100:  // needs to accept ToC
                    throw DownloadError.needToAcceptTermsAndCondition
                case 2170:  // accounts need upgrade
                    log.error(
                        "Error \(downloadList!.resultCode) : \(downloadList!.userString ?? "no user string")"
                    )
                    throw DownloadError.accountneedUpgrade(
                        errorCode: downloadList!.resultCode,
                        errorMessage: downloadList!.userString ?? "Your developer account needs to be updated"
                    )
                default:
                    // is there other error cases that I need to handle explicitly ?
                    throw DownloadError.unknownError(
                        errorCode: downloadList!.resultCode,
                        errorMessage: downloadList!.userString ?? "Unknwon error"
                    )
                }
            }
        }

        guard let dList = downloadList else {
            throw DownloadError.noDownloadsInDownloadList
        }
        return dList

    }
}
