//
//  SecretsStorageFile.swift
//  xcodeinstall
//
//  Created by Stormacq, Sebastien on 14/08/2022.
//

import CLIlib
import Logging

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

// store secrets on files in $HOME/.xcodeinstaller
struct SecretsStorageFile: SecretsHandlerProtocol {
    private let log: Logger
    private var fileManager: FileManager
    private var baseDirectory: URL
    private let cookiesPath: URL
    private let sessionPath: URL
    private let newCookiesPath: URL
    private let newSessionPath: URL

    init(log: Logger) {
        self.fileManager = FileManager.default
        self.log = log

        baseDirectory = FileHandler(log: self.log).baseFilePath()

        cookiesPath = baseDirectory.appendingPathComponent("cookies")
        sessionPath = baseDirectory.appendingPathComponent("session")

        newCookiesPath = cookiesPath.appendingPathExtension("copy")
        newSessionPath = sessionPath.appendingPathExtension("copy")
    }

    // used when testing to start from a clean place
    //    func restoreSecrets() {
    //
    //        // remove file
    //        try? fileManager.removeItem(at: sessionPath)
    //
    //        // copy backup to file
    //        try? fileManager.copyItem(at: newSessionPath, to: sessionPath)
    //
    //        // remove backup
    //        try? fileManager.removeItem(at: newSessionPath)
    //
    //        // do it again with cookies file
    //
    //        try? fileManager.removeItem(at: cookiesPath)
    //        try? fileManager.copyItem(at: newCookiesPath, to: cookiesPath)
    //        try? fileManager.removeItem(at: newCookiesPath)
    //
    //    }

    // used when testing to start from a clean place
    //    func clearSecrets(preserve: Bool = false) {
    func clearSecrets() async throws {

        //        if preserve {
        //
        //            // move files instead of deleting them (if they exist)
        //            try? fileManager.copyItem(at: cookiesPath, to: newCookiesPath)
        //            try? fileManager.copyItem(at: sessionPath, to: newSessionPath)
        //
        //        }

        try? fileManager.removeItem(at: cookiesPath)
        try? fileManager.removeItem(at: sessionPath)

    }

    // save cookies in an HTTPUrlResponse
    // save to ~/.xcodeinstall/cookies
    // merge existing cookies into file when file already exists
    func saveCookies(_ cookies: String?) async throws -> String? {

        guard let cookieString = cookies else {
            return nil
        }

        var result: String? = cookieString

        do {

            // if file exists,
            if fileManager.fileExists(atPath: cookiesPath.path) {

                // load existing cookies as [HTTPCookie]
                let existingCookies = try await self.loadCookies()

                // read it, append the new cookies and save the whole new thing
                result = try await mergeCookies(existingCookies: existingCookies, newCookies: cookies)
                try result?.data(using: .utf8)!.write(to: cookiesPath)

            } else {

                // otherwise, just save the cookies
                try cookieString.data(using: .utf8)!.write(to: cookiesPath)
            }
        } catch {
            log.error("⚠️ can not write cookies file: \(error)")
            throw error
        }

        return result

    }

    // retrieve cookies
    func loadCookies() async throws -> [HTTPCookie] {

        // read the raw file saved on disk
        let cookieLongString = try String(contentsOf: cookiesPath, encoding: .utf8)
        let result = cookieLongString.cookies()
        return result
    }

    // save Apple Session values as JSON
    func saveSession(_ session: AppleSession) async throws -> AppleSession {

        // save session
        try session.data().write(to: sessionPath)

        return session
    }

    // load Apple Session from JSON
    // returns nil when can not read file
    func loadSession() async throws -> AppleSession? {

        // read the raw file saved on disk
        let sessionData = try Data(contentsOf: sessionPath)
        return try AppleSession(fromData: sessionData)
    }

    //MARK: these operations are only valid on SecretsStorageAWS
    func retrieveAppleCredentials() async throws -> AppleCredentialsSecret {
        throw SecretsStorageAWSError.invalidOperation
    }
    func storeAppleCredentials(_ credentials: AppleCredentialsSecret) async throws {
        throw SecretsStorageAWSError.invalidOperation
    }
}
