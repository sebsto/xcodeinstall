//
//  AuthenticateCommand.swift
//  xcodeinstall
//
//  Created by Stormacq, Sebastien on 16/08/2022.
//

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

import SotoSecretsManager

// MARK: - CLIAuthenticationDelegate

struct CLIAuthenticationDelegate: AuthenticationDelegate, Sendable {
    let deps: AppDependencies

    func requestCredentials() async throws -> (username: String, password: String) {
        let creds = try await retrieveAppleCredentials()
        return (creds.username, creds.password)
    }

    func requestMFACode(options: [MFAOption]) async throws -> (option: MFAOption, code: String) {
        guard !options.isEmpty else {
            throw CLIError.invalidInput
        }

        // Single option — just prompt for the code
        if options.count == 1 {
            let option = options[0]
            let codeLength: Int
            let prompt: String

            switch option {
            case .trustedDevice(let len):
                codeLength = len
                prompt = "🔐 Enter your \(codeLength)-digit 2FA code: "
            case .sms(let phone, let len):
                codeLength = len
                let phoneDesc = phone.obfuscatedNumber ?? "unknown"
                prompt = "🔐 Enter the \(codeLength)-digit code sent to \(phoneDesc): "
            }

            guard let code = deps.readLine.readLine(prompt: prompt, silent: false) else {
                throw CLIError.invalidInput
            }
            return (option, code)
        }

        // Multiple options — present a menu
        display("🔐 Choose verification method:")
        for (i, option) in options.enumerated() {
            switch option {
            case .trustedDevice:
                display("  \(i + 1). Trusted device")
            case .sms(let phone, _):
                let phoneDesc = phone.numberWithDialCode ?? phone.obfuscatedNumber ?? "unknown"
                display("  \(i + 1). SMS to \(phoneDesc)")
            }
        }

        guard let choiceStr = deps.readLine.readLine(prompt: "Choice: ", silent: false),
              let choice = Int(choiceStr),
              choice > 0,
              choice <= options.count
        else {
            throw CLIError.invalidInput
        }

        let selected = options[choice - 1]

        switch selected {
        case .trustedDevice(let codeLength):
            let prompt = "🔐 Enter your \(codeLength)-digit 2FA code: "
            guard let code = deps.readLine.readLine(prompt: prompt, silent: false) else {
                throw CLIError.invalidInput
            }
            return (selected, code)
        case .sms:
            // Return empty code — the authenticator will send the SMS
            // and call requestMFACode again with just this SMS option
            return (selected, "")
        }
    }

    // MARK: - Credential retrieval (moved from XCodeInstall)

    private func display(_ msg: String, terminator: String = "\n") {
        deps.display.display(msg, terminator: terminator)
    }

    private func retrieveAppleCredentials() async throws -> AppleCredentialsSecret {

        guard let secrets = deps.secrets else {
            // no secrets backend configured, prompt interactively
            return try promptForCredentials()
        }

        var appleCredentials: AppleCredentialsSecret
        do {
            // first try on AWS Secrets Manager
            display("Retrieving Apple Developer Portal credentials...")
            appleCredentials = try await secrets.retrieveAppleCredentials()

            // empty credentials means the secret exists but has no real values
            if appleCredentials.username.isEmpty || appleCredentials.password.isEmpty {
                display("Apple credentials secret exists but is empty.")
                appleCredentials = try promptForCredentials(storingToAWS: true)
                try await secrets.storeAppleCredentials(appleCredentials)
                display("✅ Credentials stored in AWS Secrets Manager")
            }

        } catch SecretsStorageAWSError.invalidOperation {

            // we have a file secrets handler, prompt for credentials interactively
            appleCredentials = try promptForCredentials()

        } catch let error as SotoSecretsManager.SecretsManagerErrorType
            where error == .resourceNotFoundException
        {
            // the apple credentials secret doesn't exist yet in AWS Secrets Manager
            // prompt the user and create it transparently
            display("Apple credentials not found in AWS Secrets Manager, capturing them now...")
            appleCredentials = try promptForCredentials(storingToAWS: true)
            try await secrets.storeAppleCredentials(appleCredentials)
            display("✅ Credentials stored in AWS Secrets Manager")

        } catch {

            // unexpected errors, do not handle here
            throw error
        }

        return appleCredentials
    }

    private func promptForCredentials(storingToAWS: Bool = false) throws -> AppleCredentialsSecret {
        if storingToAWS {
            display(
                """
                Your Apple ID credentials will be securely stored in AWS Secrets Manager
                for future authentication.
                """
            )
        } else {
            display(
                """
                ⚠️⚠️ We prompt you for your Apple ID username, password, and two factors authentication code.
                These values are not stored anywhere. They are used to get an Apple session ID. ⚠️⚠️

                Alternatively, you may store your credentials on AWS Secrets Manager
                """
            )
        }

        guard
            let username = deps.readLine.readLine(
                prompt: "⌨️  Enter your Apple ID username: ",
                silent: false
            )
        else {
            throw CLIError.invalidInput
        }

        guard
            let password = deps.readLine.readLine(
                prompt: "⌨️  Enter your Apple ID password: ",
                silent: true
            )
        else {
            throw CLIError.invalidInput
        }

        return AppleCredentialsSecret(username: username, password: password)
    }
}

// MARK: - XCodeInstall authenticate command

extension XCodeInstall {

    func authenticate(with authenticationMethod: AuthenticationMethod) async throws {

        let auth = self.deps.authenticator
        let delegate = CLIAuthenticationDelegate(deps: self.deps)

        do {

            // delete previous session, if any
            try await self.deps.secrets?.clearSecrets()

            if authenticationMethod == .usernamePassword {
                display("Authenticating with username and password (likely to fail) ...")
            } else {
                display("Authenticating...")
            }
            try await auth.authenticate(with: authenticationMethod, delegate: delegate)
            display("✅ Authenticated.")

        } catch AuthenticationError.invalidUsernamePassword {

            // handle invalid username or password
            display("🛑 Invalid username or password.")

        } catch AuthenticationError.requires2FATrustedPhoneNumber {

            display(
                """
                🔐 Two factors authentication is enabled but no verification methods are available.
                Please ensure you have trusted devices or phone numbers configured:
                https://support.apple.com/en-us/HT204915
                """
            )

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

        } catch let error as SecretsStorageAWSError {
            display("🛑 AWS Error: \(error.localizedDescription)")

        } catch {
            display("🛑 Unexpected Error : \(error)")
        }
    }

}
