//
//  StoreSecretsCommand.swift
//  xcodeinstall
//
//  Created by Stormacq, Sebastien on 05/09/2022.
//

import Foundation
import Logging

extension XCodeInstall {

    func storeSecrets() async throws {

        guard let secretsHandler = self.secretsManager as? AWSSecretsHandler else {
            fatalError("This function requires a AWSSecretsManager")
        }

        do {
            display("""
This command captures your Apple ID username and password and store them securely in AWS Secrets Manager.
It allows this command to authenticate automatically, as long as no MFA is prompted.
""")

            guard let username = input.readLine(prompt: "⌨️  Enter your Apple ID username: ", silent: false) else {
                throw CLIError.invalidInput
            }

            guard let password = input.readLine(prompt: "⌨️  Enter your Apple ID password: ", silent: true) else {
                throw CLIError.invalidInput
            }

            let credentials = AppleCredentialsSecret(username: username, password: password)

            try await secretsHandler.storeAppleCredentials(credentials)
            display("✅ Credentials are securely stored")

        } catch {
            display("🛑 Unexpected error : \(error)")
            throw error
        }

    }
}
