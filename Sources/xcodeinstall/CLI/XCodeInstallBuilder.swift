//
//  File.swift
//  xcodeinstall
//
//  Created by Stormacq, Sebastien on 22/08/2022.
//

import Foundation
import Logging

class XCodeInstallBuilder {

    private var verbosity: Logger.Level = .warning

    private var authenticatorNeeded: Bool = false
    private var downloaderNeeded: Bool = false
    private var installerNeeded: Bool = false
    private var awsSecretsManagerNeeded: Bool = false
    private var awsRegion: String = ""

    func with(verbosityLevel: Logger.Level) -> XCodeInstallBuilder {
        self.verbosity = verbosityLevel
        return self
    }
    func withDownloader() -> XCodeInstallBuilder {
        self.downloaderNeeded = true
        return self
    }
    func withAuthenticator() -> XCodeInstallBuilder {
        self.authenticatorNeeded = true
        return self
    }
    func withInstaller() -> XCodeInstallBuilder {
        self.installerNeeded = true
        return self
    }
    func withAWSSecretsManager(region: String) -> XCodeInstallBuilder {
        self.awsSecretsManagerNeeded = true
        self.awsRegion = region
        return self
    }
    func build() throws -> XCodeInstall {

        let log = Log(logLevel: self.verbosity)
        let fileHandler = FileHandler(logger: log.defaultLogger)

        let secretsManager: SecretsHandler
        if self.awsSecretsManagerNeeded {

            // try to create a AWS Secrets Manager based Secret Handler.
            // call throws an error when region name is invalid
            guard let ash = try? AWSSecretsHandler(region: self.awsRegion, logger: log.defaultLogger) else {
                throw AWSSecretsHandlerError.invalidRegion(region: self.awsRegion)
            }
            secretsManager = ash
        } else {
            secretsManager = FileSecretsHandler(logger: log.defaultLogger)
        }

        var result: XCodeInstall?

        if authenticatorNeeded {
            let auth = AppleAuthenticator(logger: log.defaultLogger, secrets: secretsManager, fileHandler: fileHandler)
            result = XCodeInstall(authenticator: auth,
                                  secretsManager: secretsManager,
                                  logger: log.defaultLogger,
                                  fileHandler: fileHandler)
        }

        if downloaderNeeded {
            let down = AppleDownloader(logger: log.defaultLogger, secrets: secretsManager, fileHandler: fileHandler)
            result = XCodeInstall(downloader: down,
                                  secretsManager: secretsManager,
                                  logger: log.defaultLogger,
                                  fileHandler: fileHandler)
}

        if installerNeeded {
            let inst = ShellInstaller(logger: log.defaultLogger, fileHandler: fileHandler, shell: AsyncShell())
            result = XCodeInstall(installer: inst,
                                  secretsManager: secretsManager,
                                  logger: log.defaultLogger,
                                  fileHandler: fileHandler)
        }

        if result == nil { // no API class needed, this is just to Store Apple Secrets
            result = XCodeInstall(secretsManager: secretsManager,
                                  logger: log.defaultLogger,
                                  fileHandler: fileHandler)
        }

        // at this stage the guard statement ensured result is initialized
        return result!
    }
}
