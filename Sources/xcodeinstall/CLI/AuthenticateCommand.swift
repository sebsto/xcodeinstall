//
//  AuthenticateCommand.swift
//  xcodeinstall
//
//  Created by Stormacq, Sebastien on 16/08/2022.
//

import Foundation

extension XCodeInstall {

    func authenticate() async throws {

        guard let auth = authenticator else {
            throw XCodeInstallError.configurationError(msg: "Developer forgot to inject an authenticator object. " +
                                                             "Use XCodeInstallBuilder to correctly initialize this class") // swiftlint:disable:this line_length
        }

        // delete previous session, if any
        secretsManager.clearSecrets(preserve: false)

        display("""
⚠️⚠️⚠️\nThis tool prompts you for your Apple ID username, password, and two factors authentication code.
These values are not stored anywhere. They are used to get an Apple session ID.

The Session ID is securely stored on your AWS Account, using AWS Secrets Manager.
The AWS Secrets Manager secret name is "xcodeinstall_session"

""")

        guard let username = input.readLine(prompt: "⌨️  Enter your Apple ID username: ", silent: false) else {
            throw CLIError.invalidInput
        }

        guard let password = input.readLine(prompt: "⌨️  Enter your Apple ID password: ", silent: true) else {
            throw CLIError.invalidInput
        }

        do {

            display("Authenticating...")
            try await auth.startAuthentication(username: username, password: password)
            display("✅ Authenticated.")

            // handle invalid username or password
        } catch AuthenticationError.invalidUsernamePassword {
            display("🛑 Invalid username or password.")

            // handle two factors authentication
        } catch AuthenticationError.requires2FA {

            // start the 2FA dance
            do {

                let codeLength = try await auth.handleTwoFactorAuthentication()
                assert(codeLength > 0)

                let prompt = "🔐 Two factors authentication is enabled, enter your 2FA code: "
                guard let pinCode = input.readLine(prompt: prompt, silent: false) else {
                    throw CLIError.invalidInput
                }
                try await auth.twoFactorAuthentication(pin: pinCode)
                display("✅ Authenticated with MFA.")

//            } catch AuthenticationError.requires2FATrustedDevice {
//
//                display("""
// 🔐 Two factors authentication is enabled, with 4 digit code and trusted devices.
// This tool does not support this authentication at the moment.
// Please enable 2 factors authentication as described here: https://support.apple.com/en-us/HT204915
// """)
//                // Darwin.exit(-1)

            } catch AuthenticationError.requires2FATrustedPhoneNumber {

                display("""
                🔐 Two factors authentication is enabled, with 4 digit code and trusted phone numbers.
                This tool does not support SMS MFA at the moment.
                Please enable 2 factors authentication as described here: https://support.apple.com/en-us/HT204915
                """)

            }

        } catch {
            display("🛑 Unexpected Error : \(error)")
        }
    }

}
