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

        let secretsHandler = self.deps.secrets!
        do {
            // separate func for testability
            let input = try promptForCredentials()
            let credentials = AppleCredentialsSecret(username: input[0], password: input[1])

            try await secretsHandler.storeAppleCredentials(credentials)
            display("Credentials are securely stored", style: .security)

        } catch let error as SecretsStorageAWSError {
            display("AWS Error: \(error.localizedDescription)", style: .error())
            throw error
        } catch {
            display("Unexpected error : \(error)", style: .error())
            throw error
        }

    }

    func promptForCredentials() throws -> [String] {
        display(
            """

            This command captures your Apple ID username and password and store them securely in AWS Secrets Manager.
            It allows this command to authenticate automatically, as long as no MFA is prompted.

            """,
            style: .security
        )

        guard
            let username = self.deps.readLine.readLine(
                prompt: "Enter your Apple ID username: ",
                silent: false
            )
        else {
            throw CLIError.invalidInput
        }

        guard
            let password = self.deps.readLine.readLine(
                prompt: "Enter your Apple ID password: ",
                silent: true
            )
        else {
            throw CLIError.invalidInput
        }

        return [username, password]
    }

}
