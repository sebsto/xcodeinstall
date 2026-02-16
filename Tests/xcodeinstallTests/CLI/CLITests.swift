import ArgumentParser
import Foundation
import Logging
import Testing

@testable import xcodeinstall

// MARK: - CLI Tests Base
@MainActor
@Suite("CLI Tests")
final class CLITests {

    // MARK: - Test Environment
    // some tests might override the environment with more specialized mocks.
    var env = MockedEnvironment()
    var secretsHandler: SecretsHandlerProtocol!
    let log = Logger(label: "CLITests")

    init() async throws {
        self.secretsHandler = MockedSecretsHandler(env: &env)
        self.env.secrets = self.secretsHandler
        try await self.secretsHandler.clearSecrets()
    }

    // MARK: - Helper Methods
    func parse<A>(_ type: A.Type, _ arguments: [String]) throws -> A where A: AsyncParsableCommand {
        try MainCommand.parseAsRoot(arguments) as! A
    }

    func assertDisplay(deps: AppDependencies, _ msg: String) {
        let actual = (deps.display as! MockedDisplay).string
        #expect(actual == "\(msg)\n")
    }

    func assertDisplay(env: MockedEnvironment, _ msg: String) {
        let actual = (env.display as! MockedDisplay).string
        #expect(actual == "\(msg)\n")
    }

    func assertDisplay(_ msg: String) {
        assertDisplay(env: self.env, msg)
    }

    func assertDisplayStartsWith(deps: AppDependencies, _ msg: String) {
        let actual = (deps.display as! MockedDisplay).string
        #expect(actual.starts(with: msg))
    }

    func assertDisplayStartsWith(env: MockedEnvironment, _ msg: String) {
        let actual = (env.display as! MockedDisplay).string
        #expect(actual.starts(with: msg))
    }

    func assertDisplayStartsWith(_ msg: String) {
        assertDisplayStartsWith(env: self.env, msg)
    }

    func assertDisplayContains(env: MockedEnvironment, _ msg: String) {
        let allMessages = (env.display as! MockedDisplay).allMessages
        #expect(allMessages.contains(where: { $0.contains(msg) }))
    }

    func assertDisplayContains(_ msg: String) {
        assertDisplayContains(env: self.env, msg)
    }
}

// MARK: - Basic CLI Tests
extension CLITests {

    @Test("Test CLI Display Assertion")
    func testDisplayAssertion() {
        // Given
        let testMessage = "Test message"

        // When
        (env.display as! MockedDisplay).string = "\(testMessage)\n"

        // Then
        assertDisplay(testMessage)
    }

    @Test("Test CLI Display Starts With Assertion")
    func testDisplayStartsWithAssertion() {
        // Given
        let testPrefix = "Test prefix"
        let fullMessage = "Test prefix with additional content"

        // When
        (env.display as! MockedDisplay).string = fullMessage

        // Then
        assertDisplayStartsWith(testPrefix)
    }
}
