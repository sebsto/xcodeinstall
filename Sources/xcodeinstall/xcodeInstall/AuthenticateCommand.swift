//
//  AuthenticateCommand.swift
//  xcodeinstall
//
//  Created by Stormacq, Sebastien on 16/08/2022.
//

import SotoSSM

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

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
                prompt = "Enter your \(codeLength)-digit 2FA code: "
            case .sms(let phone, let len):
                codeLength = len
                let phoneDesc = phone.obfuscatedNumber ?? "unknown"
                prompt = "Enter the \(codeLength)-digit code sent to \(phoneDesc): "
            }

            guard let code = deps.readLine.readLine(prompt: prompt, silent: false) else {
                throw CLIError.invalidInput
            }
            return (option, code)
        }

        // Multiple options — present a menu
        display("Choose verification method:", style: .security)
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
            let prompt = "Enter your \(codeLength)-digit 2FA code: "
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

    private func display(_ msg: String, style: DisplayStyle) {
        deps.display.display(msg, style: style)
    }

    private func retrieveAppleCredentials() async throws -> AppleCredentialsSecret {

        guard let secrets = deps.secrets else {
            // no secrets backend configured, prompt interactively
            return try promptForCredentials()
        }

        var appleCredentials: AppleCredentialsSecret
        do {
            // first try on AWS Parameter Store
            display("Retrieving Apple Developer Portal credentials...")
            appleCredentials = try await secrets.retrieveAppleCredentials()

            // empty credentials means the parameter exists but has no real values
            if appleCredentials.username.isEmpty || appleCredentials.password.isEmpty {
                display("Apple credentials parameter exists but is empty.")
                appleCredentials = try promptForCredentials(storingToAWS: true)
                try await secrets.storeAppleCredentials(appleCredentials)
                display("Credentials stored in AWS Parameter Store", style: .security)
            }

        } catch SecretsStorageError.invalidOperation {

            // we have a file secrets handler, prompt for credentials interactively
            appleCredentials = try promptForCredentials()

        } catch let error as SSMErrorType where error == .parameterNotFound {
            // the apple credentials parameter doesn't exist yet in AWS Parameter Store
            // prompt the user and create it transparently
            display("Apple credentials not found in AWS Parameter Store, capturing them now...")
            appleCredentials = try promptForCredentials(storingToAWS: true)
            try await secrets.storeAppleCredentials(appleCredentials)
            display("Credentials stored in AWS Parameter Store", style: .security)

        } catch {

            // unexpected errors, do not handle here
            throw error
        }

        return appleCredentials
    }

    private func promptForCredentials(storingToAWS: Bool = false) throws -> AppleCredentialsSecret {
        try promptForAppleCredentials(
            context: storingToAWS ? .storingToAWS : .interactive,
            display: deps.display,
            readLine: deps.readLine
        )
    }
}

// MARK: - XCodeInstall authenticate command

extension XCodeInstall {

    /// Authenticates against the Apple Developer Portal.
    ///
    /// Errors are propagated untouched, the CLI layer renders them once
    /// (see `ErrorPresenter`).
    func authenticate(with authenticationMethod: AuthenticationMethod) async throws {

        let auth = self.deps.authenticator
        let delegate = CLIAuthenticationDelegate(deps: self.deps)

        // delete previous session, if any
        try await self.deps.secrets?.clearSecrets()

        if authenticationMethod == .usernamePassword {
            display("Authenticating with username and password (likely to fail) ...")
        } else {
            display("Authenticating...")
        }
        try await auth.authenticate(with: authenticationMethod, delegate: delegate)
        display("Authenticated.", style: .success)
    }

}
