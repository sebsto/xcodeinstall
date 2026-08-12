//
//  StoreSecretsCommand.swift
//  xcodeinstall
//
//  Created by Stormacq, Sebastien on 05/09/2022.
//

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

extension XCodeInstall {

    func storeSecrets() async throws {

        guard let secretsHandler = self.deps.secrets else {
            preconditionFailure("storeSecrets() called without a secrets backend — this is a programming error")
        }

        // separate func for testability
        let credentials = try promptForCredentials()

        try await secretsHandler.storeAppleCredentials(credentials)
        display("Credentials are securely stored", style: .security)
    }

    func promptForCredentials() throws -> AppleCredentialsSecret {
        display(
            """

            This command captures your Apple ID username and password and store them securely in AWS Parameter Store.
            It allows this command to authenticate automatically, as long as no MFA is prompted.

            """,
            style: .security
        )

        return try promptForAppleCredentials(
            context: .storingToAWS,
            display: self.deps.display,
            readLine: self.deps.readLine
        )
    }

}
