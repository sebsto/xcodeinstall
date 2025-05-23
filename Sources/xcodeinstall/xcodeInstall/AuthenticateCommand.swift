//
//  AuthenticateCommand.swift
//  xcodeinstall
//
//  Created by Stormacq, Sebastien on 16/08/2022.
//

import Foundation

extension XCodeInstall {

    func authenticate(with authenticationMethod: AuthenticationMethod) async throws {

        let auth = self.env.authenticator

        do {

            // delete previous session, if any
            try await self.env.secrets!.clearSecrets()
            let appleCredentials = try await retrieveAppleCredentials()

            if authenticationMethod == .usernamePassword {
                display("Authenticating with username and password (likely to fail) ...")
            } else {
                display("Authenticating...")
            }
            try await auth.startAuthentication(
                with: authenticationMethod,
                username: appleCredentials.username,
                password: appleCredentials.password
            )
            display("✅ Authenticated.")

        } catch AuthenticationError.invalidUsernamePassword {

            // handle invalid username or password
            display("🛑 Invalid username or password.")

        } catch AuthenticationError.requires2FA {

            // handle two factors authentication
            try await startMFAFlow()

        } catch AuthenticationError.serviceUnavailable {

            // service unavailable means that the authentication method requested is not available
            display("🛑 Requested authentication method is not available. Try with SRP.")

        } catch AuthenticationError.unableToRetrieveAppleServiceKey(let error) {

            // handle connection errors
            display(
                "🛑 Can not connect to Apple Developer Portal.\nOriginal error : \(error?.localizedDescription ?? "nil")"
            )

        } catch AuthenticationError.notImplemented(let feature) {

            // handle not yet implemented errors
            display(
                "🛑 \(feature) is not yet implemented. Try the next version of xcodeinstall when it will be available."
            )

        } catch {
            display("🛑 Unexpected Error : \(error)")
        }
    }

    // retrieve apple developer portal credentials.
    // either from AWS Secrets Manager, either interactively
    private func retrieveAppleCredentials() async throws -> AppleCredentialsSecret {

        var appleCredentials: AppleCredentialsSecret
        do {
            // first try on AWS Secrets Manager
            display("Retrieving Apple Developer Portal credentials...")
            appleCredentials = try await self.env.secrets!.retrieveAppleCredentials()

        } catch AWSSecretsHandlerError.invalidOperation {

            // we have a file secrets handler, prompt for credentials interactively
            appleCredentials = try promptForCredentials()

        } catch {

            // unexpected errors, do not handle here
            throw error
        }

        return appleCredentials
    }

    // prompt user for apple developer portal credentials interactively
    private func promptForCredentials() throws -> AppleCredentialsSecret {
        display(
            """
            ⚠️⚠️ We prompt you for your Apple ID username, password, and two factors authentication code.
            These values are not stored anywhere. They are used to get an Apple session ID. ⚠️⚠️

            Alternatively, you may store your credentials on AWS Secrets Manager
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

        return AppleCredentialsSecret(username: username, password: password)
    }

    // manage the MFA authentication sequence
    private func startMFAFlow() async throws {

        let auth = self.env.authenticator

        do {

            let codeLength = try await auth.handleTwoFactorAuthentication()
            assert(codeLength > 0)

            let prompt = "🔐 Two factors authentication is enabled, enter your 2FA code: "
            guard let pinCode = self.env.readLine.readLine(prompt: prompt, silent: false) else {
                throw CLIError.invalidInput
            }
            try await auth.twoFactorAuthentication(pin: pinCode)
            display("✅ Authenticated with MFA.")

        } catch AuthenticationError.requires2FATrustedPhoneNumber {

            display(
                """
                🔐 Two factors authentication is enabled, with 4 digits code and trusted phone numbers.
                This tool does not support SMS MFA at the moment. Please enable 2 factors authentication
                with trusted devices as described here: https://support.apple.com/en-us/HT204915
                """
            )

        }
    }

}
