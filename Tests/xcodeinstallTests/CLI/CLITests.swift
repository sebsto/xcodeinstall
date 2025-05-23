import ArgumentParser
import CLIlib
import Foundation
import Testing

@testable import xcodeinstall

// MARK: - CLI Tests Base
@MainActor
struct CLITests {

    // MARK: - Test Environment
    // some tests might override the environment with more specialized mocks.
    var env = MockedEnvironment()
    var secretsHandler: SecretsHandlerProtocol!

    init() async throws {
        self.secretsHandler = MockedSecretsHandler(env: &env)
        try await self.secretsHandler.clearSecrets()
    }

    // MARK: - Helper Methods
    func parse<A>(_ type: A.Type, _ arguments: [String]) throws -> A where A: AsyncParsableCommand {
        try MainCommand.parseAsRoot(arguments) as! A
    }

    func assertDisplay(env: Environment, _ msg: String) {
        let actual = (env.display as! MockedDisplay).string
        #expect(actual == "\(msg)\n")
    }

    func assertDisplay(_ msg: String) {
        assertDisplay(env: self.env, msg)
    }

    func assertDisplayStartsWith(env: Environment, _ msg: String) {
        let actual = (env.display as! MockedDisplay).string
        #expect(actual.starts(with: msg))
    }

    func assertDisplayStartsWith(_ msg: String) {
        assertDisplayStartsWith(env: self.env, msg)
    }
}

// MARK: - Basic CLI Tests
@MainActor
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
