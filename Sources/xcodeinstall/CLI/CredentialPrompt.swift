//
//  CredentialPrompt.swift
//  xcodeinstall
//
//  Shared helper that prompts for Apple ID credentials.
//  Used by both `storesecrets` and `authenticate` flows.
//

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// Context message shown before prompting for credentials.
enum CredentialPromptContext {
    /// Credentials will be stored in AWS Parameter Store.
    case storingToAWS
    /// One-time interactive use (not stored remotely).
    case interactive
}

/// Prompts the user for Apple ID username and password, displaying an appropriate
/// context message based on the intended use.
///
/// - Parameters:
///   - context: Determines the introductory message shown to the user.
///   - display: The display backend for output.
///   - readLine: The readline backend for input.
/// - Returns: The captured credentials.
/// - Throws: `CLIError.invalidInput` if the user provides no input.
@MainActor
func promptForAppleCredentials(
    context: CredentialPromptContext,
    display: DisplayProtocol,
    readLine: ReadLineProtocol
) throws -> AppleCredentialsSecret {

    switch context {
    case .storingToAWS:
        display.display(
            """
            Your Apple ID credentials will be securely stored in AWS Parameter Store
            for future authentication.
            """,
            style: .security
        )
    case .interactive:
        display.display(
            """
            We prompt you for your Apple ID username, password, and two factors authentication code.
            These values are not stored anywhere. They are used to get an Apple session ID.

            Alternatively, you may store your credentials on AWS Parameter Store
            """,
            style: .security
        )
    }

    guard
        let username = readLine.readLine(
            prompt: "Enter your Apple ID username: ",
            silent: false
        )
    else {
        throw CLIError.invalidInput
    }

    guard
        let password = readLine.readLine(
            prompt: "Enter your Apple ID password: ",
            silent: true
        )
    else {
        throw CLIError.invalidInput
    }

    return AppleCredentialsSecret(username: username, password: password)
}
