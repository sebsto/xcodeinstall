//
//  File.swift
//  
//
//  Created by Stormacq, Sebastien on 22/10/2022.
//

import Foundation

// https://stackoverflow.com/questions/47177036/use-resources-in-unit-tests-with-swift-package-manager

#if XCODE_BUILD
extension Foundation.Bundle {
    
    /// Returns resource bundle as a `Bundle`.
    /// Requires Xcode copy phase to locate files into `ExecutableName.bundle`;
    /// or `ExecutableNameTests.bundle` for test resources
    static var module: Bundle = {
        var thisModuleName = "xcodeinstallTests"
        var url = Bundle.main.bundleURL
        
        for bundle in Bundle.allBundles where bundle.bundlePath.hasSuffix(".xctest") {
            url = bundle.bundleURL.deletingLastPathComponent()
            thisModuleName = thisModuleName.appending("Tests")
        }
        
        url = url.appendingPathComponent("\(thisModuleName).bundle")
        
        guard let bundle = Bundle(url: url) else {
            fatalError("Foundation.Bundle.module could not load resource bundle: \(url.path)")
        }
        
        return bundle
    }()
    
    /// Directory containing resource bundle
    static var moduleDir: URL = {
        var url = Bundle.main.bundleURL
        for bundle in Bundle.allBundles where bundle.bundlePath.hasSuffix(".xctest") {
            // remove 'ExecutableNameTests.xctest' path component
            url = bundle.bundleURL.deletingLastPathComponent()
        }
        return url
    }()
    
}
#endif
