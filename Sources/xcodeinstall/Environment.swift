//
//  Environment.swift
//
//
//  Created by Stormacq, Sebastien on 22/11/2022.
//

import CLIlib
import Foundation

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/**

 a global struct to give access to classes for which I wrote tests.
 this global object allows me to simplify dependency injection */

@MainActor
protocol Environment: Sendable {
    var fileHandler: FileHandlerProtocol { get }
    var display: DisplayProtocol { get }
    var readLine: ReadLineProtocol { get }
    var progressBar: CLIProgressBarProtocol { get }
    var secrets: SecretsHandlerProtocol { get set }
    var awsSDK: AWSSecretsHandlerSDKProtocol { get }
    var authenticator: AppleAuthenticatorProtocol { get }
    var downloader: AppleDownloaderProtocol { get }
    var urlSessionData: URLSessionProtocol { get }
    func urlSessionDownload(dstFilePath: URL?, totalFileSize: Int?, startTime: Date?) -> URLSessionProtocol
}

@MainActor
struct RuntimeEnvironment: Environment {

    // Utilities classes
    var fileHandler: FileHandlerProtocol = FileHandler()

    // CLI related classes
    var display: DisplayProtocol = Display()
    var readLine: ReadLineProtocol = ReadLine()

    // progress bar
    var progressBar: CLIProgressBarProtocol = CLIProgressBar()

    // Secrets - will be overwritten by CLI when using AWS Secrets Manager
    var secrets: SecretsHandlerProtocol = FileSecretsHandler()
    var awsSDK: AWSSecretsHandlerSDKProtocol = AWSSecretsHandlerSoto()

    // Commands
    var authenticator: AppleAuthenticatorProtocol {
        AppleAuthenticator(env: self)
    }
    var downloader: AppleDownloaderProtocol {
        AppleDownloader(env: self)
    }

    // Network
    var urlSessionData: URLSessionProtocol = URLSession.shared
    func urlSessionDownload(
        dstFilePath: URL? = nil,
        totalFileSize: Int? = nil,
        startTime: Date? = nil
    ) -> URLSessionProtocol {
        URLSession(
            configuration: .default,
            delegate: DownloadDelegate(
                env: self,
                dstFilePath: dstFilePath,
                totalFileSize: totalFileSize,
                startTime: startTime,
                semaphore: DispatchSemaphore(value: 0)
            ),
            delegateQueue: nil
        )
    }
}
