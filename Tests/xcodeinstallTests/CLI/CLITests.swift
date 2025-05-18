import ArgumentParser
import CLIlib
import Foundation
import Testing

@testable import xcodeinstall

// MARK: - CLI Tests Base
@MainActor
struct CLITests {

    // MARK: - Test Environment
    var env: Environment!
    var secretsHandler: SecretsHandlerProtocol!

    init() async throws {
        // Setup environment for each test
        self.env = createTestEnvironment()
        self.secretsHandler = MockedSecretsHandler(env: env)
        try await self.secretsHandler.clearSecrets()
    }

    // MARK: - Helper Methods
    func parse<A>(_ type: A.Type, _ arguments: [String]) throws -> A where A: AsyncParsableCommand {
        try MainCommand.parseAsRoot(arguments) as! A
    }

    func assertDisplay(_ msg: String) -> Bool {
        let actual = (env.display as! MockedDisplay).string
        return actual == "\(msg)\n"
    }

    func assertDisplayStartsWith(_ msg: String) -> Bool {
        let actual = (env.display as! MockedDisplay).string
        return actual.starts(with: msg)
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
        #expect(assertDisplay(testMessage))
    }

    @Test("Test CLI Display Starts With Assertion")
    func testDisplayStartsWithAssertion() {
        // Given
        let testPrefix = "Test prefix"
        let fullMessage = "Test prefix with additional content"

        // When
        (env.display as! MockedDisplay).string = fullMessage

        // Then
        #expect(assertDisplayStartsWith(testPrefix))
    }
}
