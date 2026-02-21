//
//  Environment.swift
//
//
//  Created by Stormacq, Sebastien on 22/11/2022.
//

import Logging

// MARK: - AppDependencies

struct AppDependencies: Sendable {
    let fileHandler: FileHandlerProtocol
    var display: DisplayProtocol
    var readLine: ReadLineProtocol
    var progressBar: ProgressBarProtocol
    var secrets: SecretsHandlerProtocol?
    var authenticator: AppleAuthenticatorProtocol
    var downloader: AppleDownloaderProtocol
    let urlSessionData: URLSessionProtocol
    let shell: any ShellExecuting
    let log: Logger
}
