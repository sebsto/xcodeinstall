# Swift-testing Migration Guide

This document provides instructions for migrating the remaining tests from XCTest to Swift-testing.

## Overview of Changes

The project has been updated to use Swift-testing instead of XCTest. The following changes have been made:

1. Added Swift-testing dependency to Package.swift
2. Created a new TestingSupport.swift file with utilities for Swift-testing
3. Updated TestHelper.swift to work with Swift-testing
4. Migrated some test files to Swift-testing as examples

## Migration Steps for Remaining Tests

Follow these steps to migrate the remaining test files:

### 1. Update Imports

Replace:
```swift
import XCTest
```

With:
```swift
import Testing
```

### 2. Convert Test Classes to Structs with @Suite

Replace:
```swift
class MyTest: XCTestCase {
    // Test methods
}
```

With:
```swift
@Suite("My Test Description")
struct MyTest {
    // Test methods
}
```

For tests that extend HTTPClientTestCase, add a testSuite property:
```swift
@Suite("My Test Description")
struct MyTest {
    var testSuite = HTTPClientTestSuite()
    
    // Test methods that call testSuite.setUp() and use testSuite properties
}
```

### 3. Convert setUp and tearDown Methods

Replace:
```swift
override func setUpWithError() throws {
    // Setup code
}

override func tearDownWithError() throws {
    // Teardown code
}
```

With:
```swift
@Lifecycle
mutating func setUp() {
    // Setup code
}

@Lifecycle
func tearDown() {
    // Teardown code
}
```

### 4. Convert Test Methods

Replace:
```swift
func testSomething() throws {
    // Test code
}
```

With:
```swift
@Test("Description of the test")
func testSomething() throws {
    // Test code
}
```

### 5. Convert Assertions

Replace XCTest assertions with Swift-testing assertions:

| XCTest | Swift-testing |
|--------|--------------|
| `XCTAssert(condition)` | `#expect(condition)` |
| `XCTAssertEqual(a, b)` | `#expect(a == b)` |
| `XCTAssertNotEqual(a, b)` | `#expect(a != b)` |
| `XCTAssertNil(a)` | `#expect(a == nil)` |
| `XCTAssertNotNil(a)` | `#expect(a != nil)` |
| `XCTAssertTrue(a)` | `#expect(a)` |
| `XCTAssertFalse(a)` | `#expect(!a)` |
| `XCTAssertThrowsError(try expression)` | `#expect(throws: Error.self) { try expression }` |
| `XCTAssertNoThrow(try expression)` | Just use `try expression` |

### 6. Handle Async Tests

For async tests, make sure to:
1. Mark the test method with `async throws`
2. Call `try await testSuite.setUp()` at the beginning of the test
3. Use async/await syntax directly (no need for the old AsyncTestCase helpers)

### 7. Error Handling

Replace:
```swift
do {
    try someOperation()
    XCTAssert(false, "Expected an error")
} catch SomeError.specificError {
    // Expected
} catch {
    XCTAssert(false, "Unexpected error: \(error)")
}
```

With:
```swift
do {
    try someOperation()
    #expect(false, "Expected an error")
} catch let error as SomeError {
    if case .specificError = error {
        // Expected
    } else {
        #expect(false, "Expected specificError but got \(error)")
    }
} catch {
    #expect(false, "Unexpected error: \(error)")
}
```

Or use the simpler form when possible:
```swift
#expect(throws: SomeError.specificError) {
    try someOperation()
}
```

## Examples

See the following files for examples of migrated tests:
- `Tests/xcodeinstallTests/API/ListTest.swift`
- `Tests/xcodeinstallTests/Utilities/FileHandlerTest.swift`

## Testing Support

The `TestingSupport.swift` file provides utilities to help with testing:

- `HTTPClientTestSuite`: A struct that replaces the HTTPClientTestCase class
- `runAsyncAndWait`: A utility function for running async code in synchronous contexts

## Resources

- [Swift-testing Documentation](https://github.com/apple/swift-testing)
- [Swift-testing API Reference](https://swiftpackageindex.com/apple/swift-testing/documentation)