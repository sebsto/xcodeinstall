//
//  ErrorPresenter.swift
//  xcodeinstall
//
//  Single point of translation between errors and user-facing output.
//

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// The user-facing rendering of an error: what to display, and whether the
/// process must terminate with a failure.
struct ErrorPresentation {

    struct Message {
        let text: String
        let style: DisplayStyle
    }

    /// The messages to display, in order. Empty when the error must stay silent.
    let messages: [Message]

    /// `true` when the process must terminate with a failure exit code.
    let isFailure: Bool
}

extension ErrorPresentation {

    /// Nothing to display and no failure: the user deliberately interrupted the command.
    static let silent = ErrorPresentation(messages: [], isFailure: false)

    static func failure(_ text: String, style: DisplayStyle = .error()) -> ErrorPresentation {
        ErrorPresentation(messages: [Message(text: text, style: style)], isFailure: true)
    }

    static func failure(_ messages: Message...) -> ErrorPresentation {
        ErrorPresentation(messages: messages, isFailure: true)
    }
}

/// Turns any error thrown by the business logic into the text the user sees.
///
/// The `XCodeInstall` layer only throws, it never renders errors. The CLI layer
/// (`MainCommand`) calls this presenter from a single place per subcommand. As a
/// result an error is rendered exactly once, whichever code path produced it —
/// including errors that bubble up through a nested command, such as `download`
/// asking `list` for the list of available files.
enum ErrorPresenter {

    private static let bugReportURL =
        "https://github.com/sebsto/xcodeinstall/issues/new?assignees=&labels=&template=bug_report.md&title="

    static func presentation(for error: Error) -> ErrorPresentation {
        switch error {
        case let error as CLIError:
            return presentation(for: error)
        case let error as DownloadError:
            return presentation(for: error)
        case let error as AuthenticationError:
            return presentation(for: error)
        case let error as InstallerError:
            return presentation(for: error)
        case let error as FileHandlerError:
            return presentation(for: error)
        case let error as SecretsStorageAWSError:
            return .failure("AWS Error: \(error.localizedDescription)")
        default:
            return .failure(unexpected(error))
        }
    }

    // MARK: - Per error type

    private static func presentation(for error: CLIError) -> ErrorPresentation {
        switch error {
        case .userCancelled:
            // the user pressed enter on a prompt, there is nothing to report
            return .silent
        case .invalidInput:
            return .failure("Invalid input")
        }
    }

    private static func presentation(for error: DownloadError) -> ErrorPresentation {
        switch error {
        case .authenticationRequired:
            return .failure(
                "Session expired, you need to re-authenticate.",
                style: .error(nextSteps: ["xcodeinstall authenticate"])
            )
        case .unknownFile(let file):
            return .failure("Unknown file name : \(file)")
        case .accountNeedUpgrade(let errorCode, let errorMessage):
            return .failure("\(errorMessage) (Apple Portal error code : \(errorCode))")
        case .needToAcceptTermsAndCondition:
            return .failure(
                """
                This is a new Apple account, you need first to accept the developer terms of service.
                Open a session at https://developer.apple.com/register/agree/
                Read and accept the ToS and try again.
                """
            )
        case .unknownError(let errorCode, let errorMessage):
            return .failure(
                Message(text: "\(errorMessage) (Unhandled download error : \(errorCode))", style: .error()),
                bugReportMessage
            )
        default:
            return .failure(
                Message(text: "Unknown download error : \(error)", style: .error()),
                bugReportMessage
            )
        }
    }

    private static func presentation(for error: AuthenticationError) -> ErrorPresentation {
        switch error {
        case .invalidUsernamePassword:
            return .failure("Invalid username or password.")
        case .requires2FATrustedPhoneNumber:
            return .failure(
                """
                Two factors authentication is enabled but no verification methods are available.
                Please ensure you have trusted devices or phone numbers configured:
                https://support.apple.com/en-us/HT204915
                """,
                style: .security
            )
        case .serviceUnavailable:
            // the authentication method requested is not available
            return .failure("Requested authentication method is not available. Try with SRP.")
        case .unableToRetrieveAppleServiceKey(let underlyingError):
            return .failure(
                """
                Can not connect to Apple Developer Portal.
                Original error : \(underlyingError?.localizedDescription ?? "nil")
                """
            )
        case .notImplemented(let featureName):
            return .failure(
                "\(featureName) is not yet implemented. Try the next version of xcodeinstall when it will be available."
            )
        default:
            return .failure(unexpected(error))
        }
    }

    private static func presentation(for error: InstallerError) -> ErrorPresentation {
        switch error {
        case .unsupportedInstallation:
            return .failure("Unsupported installation type. (We support Xcode XIP files and Command Line Tools PKG)")
        case .xCodeXIPInstallationError:
            return .failure("Can not expand XIP file. Is there enough space on / ? (16GiB required)")
        case .xCodeMoveInstallationError:
            return .failure("Can not move Xcode to /Applications")
        case .xCodePKGInstallationError:
            return .failure("Can not install additional packages.")
        case .existingXcodeAppIsNotSymlink:
            return .failure(
                "/Applications/Xcode.app exists and is not a symlink. Please rename or remove it before installing a versioned Xcode."
            )
        case .xcodeSelectFailed:
            return .failure("Failed to run xcode-select to activate Xcode")
        case .unableToListInstalledXcodes:
            return .failure("Failed to list installed Xcode versions")
        case .noInstalledXcodeVersions:
            return .failure("No versioned Xcode installations found in /Applications", style: .warning)
        case .xcodeVersionNotInstalled(let version):
            return .failure("Xcode \(version) is not installed in /Applications")
        default:
            return .failure(unexpected(error))
        }
    }

    private static func presentation(for error: FileHandlerError) -> ErrorPresentation {
        switch error {
        case .noDownloadedList:
            return .failure("There is no downloaded file to be installed", style: .warning)
        case .fileDoesNotExist:
            return .failure(unexpected(error))
        }
    }

    // MARK: - Shared messages

    private static var bugReportMessage: ErrorPresentation.Message {
        Message(text: "Please file an error report at \(bugReportURL)", style: .normal)
    }

    private static func unexpected(_ error: Error) -> String {
        "Unexpected error : \(error)"
    }
}

private typealias Message = ErrorPresentation.Message
