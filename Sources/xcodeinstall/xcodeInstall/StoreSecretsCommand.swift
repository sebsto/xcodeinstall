//
//  StoreSecretsCommand.swift
//  xcodeinstall
//
//  Created by Stormacq, Sebastien on 05/09/2022.
//

import Foundation

extension XCodeInstall {

    func storeSecrets() async throws {

        let secretsHandler = self.env.secrets!
        do {
            // separate func for testability
            let input = try promptForCredentials()
            let credentials = AppleCredentialsSecret(username: input[0], password: input[1])

            try await secretsHandler.storeAppleCredentials(credentials)
            display("✅ Credentials are securely stored")

        } catch {
            display("🛑 Unexpected error : \(error)")
            throw error
        }

    }

    func promptForCredentials() throws -> [String] {
        display(
            """

            This command captures your Apple ID username and password and store them securely in AWS Secrets Manager.
            It allows this command to authenticate automatically, as long as no MFA is prompted.

            """
        )

        guard
            let username = self.env.readLine.readLine(
                prompt: "⌨️  Enter your Apple ID username: ",
                silent: false
            )
        else {
            throw CLIError.invalidInput
        }

        guard
            let password = self.env.readLine.readLine(
                prompt: "⌨️  Enter your Apple ID password: ",
                silent: true
            )
        else {
            throw CLIError.invalidInput
        }

        return [username, password]
    }

}
