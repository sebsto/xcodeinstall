//
//  EnvironmentMock.swift
//
//
//  Created by Stormacq, Sebastien on 22/11/2022.
//

import CLIlib
import Foundation

@testable import xcodeinstall

struct MockedEnvironment: Environment {

    var fileHandler: FileHandlerProtocol = MockedFileHandler()

    var display: DisplayProtocol = MockedDisplay()
    var readLine: ReadLineProtocol = MockedReadLine()
    var progressBar: CLIProgressBarProtocol = MockedProgressBar()

    var secrets: SecretsHandlerProtocol {
        get { MockedSecretsHandler(env: self) }
        set {}
    }
    var awsSDK: AWSSecretsHandlerSDKProtocol = try! MockedAWSSecretsHandlerSDK()

    var authenticator: AppleAuthenticatorProtocol = MockedAppleAuthentication()
    var downloader: AppleDownloaderProtocol = MockedAppleDownloader()

    var urlSessionData: URLSessionProtocol = MockedURLSession()

    func urlSessionDownload(
        dstFilePath: URL? = nil,
        totalFileSize: Int? = nil,
        startTime: Date? = nil
    ) -> any xcodeinstall.URLSessionProtocol {
        MockedURLSession()
    }

}
