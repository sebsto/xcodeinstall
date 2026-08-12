//
//  CLIErrorPresentation.swift
//  xcodeinstall
//
//  The one place where a subcommand turns an error into output and an exit code.
//

import ArgumentParser

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

extension MainCommand {

    /// Builds the `XCodeInstall` facade, reporting a construction failure to the user.
    ///
    /// Construction happens before the dependencies exist, so the error is displayed on a
    /// freshly built `NooraDisplay` rather than on `xci.deps.display`.
    static func makeXCodeInstall(
        with deps: AppDependencies?,
        for region: String? = nil,
        profileName: String? = nil,
        verbose: Bool
    ) async throws -> XCodeInstall {
        do {
            return try await XCodeInstaller(
                with: deps,
                for: region,
                profileName: profileName,
                verbose: verbose
            )
        } catch {
            await presentOnTerminal(error)
            throw ExitCode.failure
        }
    }

    /// Runs the body of a subcommand, displaying any error exactly once and mapping it
    /// to the process exit code.
    ///
    /// The `XCodeInstall` layer only throws — this is the single place where errors
    /// become output, which is what keeps a nested failure (`download` → `list`) from
    /// being reported twice.
    static func run(on xci: XCodeInstall, _ body: () async throws -> Void) async throws {
        do {
            try await body()
        } catch {
            let presentation = await present(error, for: xci)

            // Gracefully shut down AWS client before process exits
            // to avoid RotatingCredentialProvider crash during deallocation
            try? await xci.deps.secrets?.shutdown()

            guard presentation.isFailure else { return }
            throw ExitCode.failure
        }

        // Gracefully shut down AWS client before process exits
        // to avoid RotatingCredentialProvider crash during deallocation
        try? await xci.deps.secrets?.shutdown()
    }

    // MARK: - Rendering

    @MainActor
    private static func present(_ error: Error, for xci: XCodeInstall) -> ErrorPresentation {
        present(error, on: xci.deps.display)
    }

    @MainActor
    private static func presentOnTerminal(_ error: Error) {
        present(error, on: NooraDisplay())
    }

    @MainActor
    @discardableResult
    private static func present(_ error: Error, on display: DisplayProtocol) -> ErrorPresentation {
        let presentation = ErrorPresenter.presentation(for: error)
        for message in presentation.messages {
            display.display(message.text, style: message.style)
        }
        return presentation
    }
}
