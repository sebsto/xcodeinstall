//
//  TestHelper.swift
//  xcodeinstallTests
//
//  Created by Stormacq, Sebastien on 04/08/2022.
//

import Foundation
import XCTest

@testable import xcodeinstall

enum TestData: String {
    case downloadList = "download-list-20231115"
    case downloadError = "download-error"
    case downloadUnknownError = "download-unknown-error"
}

// return the URL of a test file
func urlForTestData(file: TestData) throws -> URL {
    // load list from file
    // https://stackoverflow.com/questions/47177036/use-resources-in-unit-tests-with-swift-package-manager
    let filePath = Bundle.module.path(forResource: file.rawValue, ofType: "json")!
    return URL(fileURLWithPath: filePath)
}

// load a test file added as a resource to the executable bundle
func loadTestData(file: TestData) throws -> Data {
    // load list from file
    try Data(contentsOf: urlForTestData(file: file))
}

@MainActor
func createDownloadList() throws {

    let fm = FileManager.default

    // copy test file at destination

    // delete file at destination if it exists
    if fm.fileExists(atPath: FileHandler().downloadListPath().path) {
        XCTAssertNoThrow(try fm.removeItem(at: FileHandler().downloadListPath()))
    }
    // get the source URL
    guard let testFilePath = try? urlForTestData(file: .downloadList) else {
        fatalError("Can not retrieve url for \(TestData.downloadList.rawValue)")
    }
    // copy source to destination
    XCTAssertNoThrow(try fm.copyItem(at: testFilePath, to: FileHandler().downloadListPath()))
}

@MainActor
func deleteDownloadList() {

    let fm = FileManager.default

    // remove test file from destination
    if fm.fileExists(atPath: FileHandler().downloadListPath().path) {
        XCTAssertNoThrow(try fm.removeItem(at: FileHandler().downloadListPath()))
    }
}

// https://stackoverflow.com/questions/47177036/use-resources-in-unit-tests-with-swift-package-manager
//#if XCODE_BUILD - also defined in swiftpm, I use a custom flag defined in Package.swift instead
// #if !SWIFTPM_COMPILATION
// extension Foundation.Bundle {

//     /// Returns resource bundle as a `Bundle`.
//     /// Requires Xcode copy phase to locate files into `ExecutableName.bundle`;
//     /// or `ExecutableNameTests.bundle` for test resources
//     static var module: Bundle = {
//         var thisModuleName = "xcodeinstall"
//         var url = Bundle.main.bundleURL

//         for bundle in Bundle.allBundles where bundle.bundlePath.hasSuffix(".xctest") {
//             url = bundle.bundleURL.deletingLastPathComponent()
//             thisModuleName = thisModuleName.appending("Tests")
//         }

//         url = url.appendingPathComponent("\(thisModuleName).xctest")

//         guard let bundle = Bundle(url: url) else {
//             fatalError("Foundation.Bundle.module could not load resource bundle: \(url.path)")
//         }

//         return bundle
//     }()

//     /// Directory containing resource bundle
//     static var moduleDir: URL = {
//         var url = Bundle.main.bundleURL
//         for bundle in Bundle.allBundles where bundle.bundlePath.hasSuffix(".xctest") {
//             // remove 'ExecutableNameTests.xctest' path component
//             url = bundle.bundleURL.deletingLastPathComponent()
//         }
//         return url
//     }()
// }
// #endif
