//
//  TestHelper.swift
//  xcodeinstallTests
//
//  Created by Stormacq, Sebastien on 04/08/2022.
//

import Foundation

/// Returns the directory where test specifications should be stored.
///
/// The default directory is determined relative to the first calling source file based on the assumption that that it is in a Swift Package Manager test target, and not in any further subdirectories.
@inlinable func testDataDirectory(_ callerLocation: StaticString = #file) -> URL {
    
    let repositoryRoot = URL(fileURLWithPath: String(describing: callerLocation)).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    
    return repositoryRoot.appendingPathComponent("Data")
    
}
