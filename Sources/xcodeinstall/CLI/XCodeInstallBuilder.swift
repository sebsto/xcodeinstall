//
//  File.swift
//  xcodeinstall
//
//  Created by Stormacq, Sebastien on 22/08/2022.
//

import Foundation
import CLIlib

class XCodeInstallBuilder {

    private var authenticatorNeeded: Bool = false
    private var downloaderNeeded: Bool = false
    private var installerNeeded: Bool = false
    private var awsSecretsManagerNeeded: Bool = false
    private var verbosityNeeded: Bool = false
    private var awsRegion: String = ""

    func withVerbosity(verbose: Bool) -> XCodeInstallBuilder {
        self.verbosityNeeded = verbose 
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

        var result: XCodeInstall?
        let fileHandler = FileHandler()

        let secretsManager: SecretsHandler
        if self.awsSecretsManagerNeeded {

            // try to create a AWS Secrets Manager based Secret Handler.
            // call throws an error when region name is invalid
            guard let ash = try? AWSSecretsHandler(region: self.awsRegion) else {
                throw AWSSecretsHandlerError.invalidRegion(region: self.awsRegion)
            }
            secretsManager = ash
        } else {
            secretsManager = FileSecretsHandler()
        }

        if verbosityNeeded {
            log = Log.verboseLogger(label: "xcodeinstall")
        } else {
            log = Log.defaultLogger(label: "xcodeinstall")
        }

        if authenticatorNeeded {
            let auth = AppleAuthenticator(secrets: secretsManager, fileHandler: fileHandler)
            result = XCodeInstall(authenticator: auth,
                                  secretsManager: secretsManager,
                                  fileHandler: fileHandler)
        }

        if downloaderNeeded {
            let down = AppleDownloader(secrets: secretsManager, fileHandler: fileHandler)
            result = XCodeInstall(downloader: down,
                                  secretsManager: secretsManager,
                                  fileHandler: fileHandler)
}

        if installerNeeded {
            let inst = ShellInstaller(fileHandler: fileHandler, shell: AsyncShell())
            result = XCodeInstall(installer: inst,
                                  secretsManager: secretsManager,
                                  fileHandler: fileHandler)
        }

        if result == nil { // no API class needed, this is just to Store Apple Secrets
            result = XCodeInstall(secretsManager: secretsManager,
                                  fileHandler: fileHandler)
        }

        // at this stage the guard statement ensured result is initialized
        return result!
    }
}
