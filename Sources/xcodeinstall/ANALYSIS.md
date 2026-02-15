The core issue is that Environment is a "god protocol" acting as a service locator. Every dependency lives in one bag, and classes like HTTPClient hold a mutable var environment: Environment? = nil that gets set after init. This creates several problems in Swift 6:

RuntimeEnvironment is a final class conforming to Sendable, but it has mutable state (_secrets, _authenticator, _downloader, display, readLine, progressBar) without any isolation. Right now this compiles because of @MainActor default isolation from your Package.swift, but it's fragile and semantically wrong for non-UI code.

The HTTPClient pattern of var environment: Environment? = nil with a fatalError guard is a runtime crash waiting to happen. It's also a two-phase init anti-pattern that makes the dependency graph circular: RuntimeEnvironment creates AppleAuthenticator, but AppleAuthenticator needs environment set back to RuntimeEnvironment later (the getter does (self._authenticator as? AppleAuthenticator)?.environment = self).

DownloadManager has the same problem: var env: Environment? = nil set after construction.

Here's what I'd recommend, in order of impact:

1. Break the god protocol into focused protocols

Instead of one Environment that knows about files, display, secrets, networking, and shell execution, define small protocols per concern:

protocol FileHandling: Sendable {
    var fileHandler: FileHandlerProtocol { get }
}

protocol SecretStorage: Sendable {
    var secrets: SecretsHandlerProtocol { get }
}

protocol NetworkSession: Sendable {
    var urlSessionData: URLSessionProtocol { get }
    var downloadManager: DownloadManager { get }
}

protocol ShellExecutor: Sendable {
    func run(_ executable: Executable, arguments: Arguments, workingDirectory: FilePath?) async throws -> ShellOutput
}
Then each type declares only what it actually needs. HTTPClient would take SecretStorage & NetworkSession. AppleDownloader would take SecretStorage & NetworkSession & FileHandling. The CLI layer would compose them all.

2. Use constructor injection with structs instead of mutable properties

The circular dependency (Environment → AppleAuthenticator → Environment) exists because HTTPClient is a class with a mutable environment property. Break this by passing dependencies through init:

final class HTTPClient: Sendable {
    let secrets: SecretsHandlerProtocol
    let urlSession: URLSessionProtocol
    let log: Logger

    init(secrets: SecretsHandlerProtocol, urlSession: URLSessionProtocol, log: Logger) {
        self.secrets = secrets
        self.urlSession = urlSession
        self.log = log
    }
}
No more optional environment, no more fatalError("Environment not set"), no more two-phase init.

3. Use a simple DI container struct for composition at the top level

Replace the Environment class with a plain struct that just holds the concrete instances. This is your composition root, used only in CLIMain and tests:

struct AppDependencies: Sendable {
    let fileHandler: FileHandlerProtocol
    let secrets: SecretsHandlerProtocol
    let urlSession: URLSessionProtocol
    let downloadManager: DownloadManager
    let display: DisplayProtocol
    let readLine: ReadLineProtocol
    let progressBar: CLIProgressBarProtocol
    let log: Logger
    let shellExecutor: ShellExecutor
}
The CLI entry point builds this once and passes individual pieces to each subsystem. Tests build a AppDependencies with mocks. No protocol needed for the container itself.

4. Eliminate the circular dependency

The current cycle is: RuntimeEnvironment.init() creates AppleAuthenticator(log:), then the authenticator getter patches environment back in. Instead:

// In CLIMain.XCodeInstaller:
let secrets = SecretsStorageFile(log: logger)
let urlSession = URLSession.shared
let authenticator = AppleAuthenticator(secrets: secrets, urlSession: urlSession, log: logger)
let downloader = AppleDownloader(secrets: secrets, urlSession: urlSession, fileHandler: fileHandler, log: logger)
Each object gets exactly what it needs at construction. No back-patching.

5. For Sendable safety, prefer value types or actors for mutable state

DownloadManager has mutable env and downloadTarget properties. Since it's a class, this is a data race risk. Two options:

Make it a struct and pass everything through the download method
Make it an actor if it truly needs mutable state across calls
Given that downloadTarget and env are set once before download() is called, the cleanest approach is to pass them as parameters:

struct DownloadManager: Sendable {
    let log: Logger

    func download(
        from url: String,
        target: DownloadTarget,
        secrets: SecretsHandlerProtocol,
        fileHandler: FileHandlerProtocol
    ) async throws -> AsyncThrowingStream<DownloadProgress, Error> {
        // ...
    }
}
Migration path (incremental, one PR at a time):

1. First, make HTTPClient take its dependencies through init (secrets + urlSession). This breaks the circular dependency and removes the fatalError paths.
2. Do the same for DownloadManager — pass DownloadTarget, secrets, and fileHandler as method parameters.
3. Split the Environment protocol into focused protocols. Types that currently take Environment now take only the subset they need.
4. Replace RuntimeEnvironment class with a struct composition root in CLIMain.
5. Update MockedEnvironment in tests — it becomes simpler since each test only mocks the protocols it cares about.

The end result: no god object, no optional properties with fatalError, no circular dependencies, no two-phase init, and full Sendable safety without needing @MainActor on non-UI code. Each step is independently shippable and testable.