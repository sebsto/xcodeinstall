//
//  FileSecretsHandler.swift
//  xcodeinstall
//
//  Created by Stormacq, Sebastien on 14/08/2022.
//

import Foundation
import Logging

// store secrets on files in $HOME/.xcodeinstaller
struct FileSecretsHandler: SecretsHandler {

    private let logger: Logger

    private let fileManager: FileManager
    private let baseDirectory: URL
    private let cookiesPath: URL
    private let sessionPath: URL
    private(set) var downloadListPath: URL
    private let newCookiesPath: URL
    private let newSessionPath: URL

    init(logger: Logger) {

        self.logger = logger

        fileManager = FileManager()

        let fileHandler = FileHandler(logger: logger)

        baseDirectory = fileHandler.baseFilePath()

        cookiesPath = baseDirectory.appendingPathComponent("cookies")
        sessionPath = baseDirectory.appendingPathComponent("session")

        downloadListPath = baseDirectory.appendingPathComponent("downloadList")

        newCookiesPath = cookiesPath.appendingPathExtension("copy")
        newSessionPath = sessionPath.appendingPathExtension("copy")
    }

    // used when testing to start from a clean place
    func restoreSecrets() {

        // remove file
        try? fileManager.removeItem(at: sessionPath)

        // copy backup to file
        try? fileManager.copyItem(at: newSessionPath, to: sessionPath)

        // remove backup
        try? fileManager.removeItem(at: newSessionPath)

        // do it again with cookies file

        try? fileManager.removeItem(at: cookiesPath)
        try? fileManager.copyItem(at: newCookiesPath, to: cookiesPath)
        try? fileManager.removeItem(at: newCookiesPath)

    }

    // used when testing to start from a clean place
    func clearSecrets(preserve: Bool = false) {

        if preserve {

            // move files instead of deleting them (if they exist)
            try? fileManager.copyItem(at: cookiesPath, to: newCookiesPath)
            try? fileManager.copyItem(at: sessionPath, to: newSessionPath)

        }

        try? fileManager.removeItem(at: cookiesPath)
        try? fileManager.removeItem(at: sessionPath)

    }

    // save cookies in an HTTPUrlResponse
    // save to ~/.xcodeinstall/cookies
    // merge existing cookies into file when file already exists
    func saveCookies(_ cookies: String?) throws -> String? {

        guard let cookieString = cookies else {
            return nil
        }

        var result: String? = cookieString

        do {

            // if file exists,
            if fileManager.fileExists(atPath: cookiesPath.path) {

                // read it, append the new cookies and save the whole new thing

                // load existing cookies as [HTTPCookie]
                var existingCookies = try self.loadCookies()

                // transform received cookie string into [HTTPCookie]
                let newCookies = cookieString.cookies()

                // merge cookies, new values have priority

                // browse new cookies
                for newCookie in newCookies {

                    // if a newCookie match an existing one
                    if ( existingCookies.contains { cookie in cookie.name == newCookie.name }) {

                        // replace old with new
                        // assuming there is only one !!
                        existingCookies.removeAll { cookie in cookie.name == newCookie.name }
                        existingCookies.append(newCookie)
                    } else {
                        // add new to existing
                        existingCookies.append(newCookie)
                    }

                }

                // save new set of cookie as string
                result = existingCookies.string()
                try result?.data(using: .utf8)!.write(to: cookiesPath)

            } else {
                // otherwise, just save the cookies
                try cookieString.data(using: .utf8)!.write(to: cookiesPath)
            }
        } catch {
            logger.error("⚠️ can not write cookies file: \(error)")
        }

        return result

    }

    // retrieve cookies
    func loadCookies() throws -> [HTTPCookie] {

        // read the raw file saved on disk
        let cookieLongString = try String(contentsOf: cookiesPath, encoding: .utf8)
        let result = cookieLongString.cookies()
        return result
    }

    // save Apple Session values as JSON
    func saveSession(_ session: AppleSession) throws -> AppleSession {

        // save session
        let data = try JSONEncoder().encode(session)

        try data.write(to: sessionPath)

        return session
    }

    // load Apple Session from JSON
    func loadSession() throws -> AppleSession {

        // read the raw file saved on disk
        let sessionData = try Data(contentsOf: sessionPath)

        return try JSONDecoder().decode(AppleSession.self, from: sessionData)
    }

    func saveDownloadList(list: DownloadList) throws -> DownloadList {

        // save list
        let data = try JSONEncoder().encode(list)
        try data.write(to: downloadListPath)

        return list

    }

    func loadDownloadList() throws -> DownloadList {

        // read the raw file saved on disk
        let listData = try Data(contentsOf: downloadListPath)

        return try JSONDecoder().decode(DownloadList.self, from: listData)
    }
}
