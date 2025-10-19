//
//  TestHelper.swift
//  xcodeinstallTests
//
//  Created by Stormacq, Sebastien on 04/08/2022.
//

import Foundation
import Logging

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

func createDownloadList() throws {
    let fm = FileManager.default
    let log = Logger(label: "TEST createDownloadList")
    
    // delete file at destination if it exists
    let downloadListPath = FileHandler(log: log).downloadListPath()
    if fm.fileExists(atPath: downloadListPath.path) {
        try fm.removeItem(at: downloadListPath)
    }
    
    // get the source URL and copy to destination
    let testFilePath = try urlForTestData(file: .downloadList)
    try fm.copyItem(at: testFilePath, to: downloadListPath)
}

func deleteDownloadList() throws {
    let fm = FileManager.default
    let log = Logger(label: "TEST deleteDownloadList")
    
    // remove test file from destination
    let downloadListPath = FileHandler(log: log).downloadListPath()
    if fm.fileExists(atPath: downloadListPath.path) {
        try fm.removeItem(at: downloadListPath)
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
