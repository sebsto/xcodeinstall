//
//  XcodeInstallBuilderTest.swift
//  xcodeinstallTests
//
//  Created by Stormacq, Sebastien on 17/08/2022.
//

import XCTest
// import Logging 
@testable import xcodeinstall

class XcodeInstallBuilderTest: XCTestCase {
    
    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testBuildXCodeWithVerbosity() throws {
        
        // given
        // when
        let xci = try? XCodeInstallBuilder()
            .withVerbosity(verbose: true)
            .build()
        
        // then
        XCTAssertNotNil(xci)

        // TODO how can I test logger is verbose ?
        //XCTAssertNotNil(log.logLevel == .debug)
        
    }


    func testBuildXCodeWithAuthenticator() throws {
        
        // given
        // when
        let xci = try? XCodeInstallBuilder()
            .withAuthenticator()
            .build()
        
        // then
        XCTAssertNotNil(xci)
        XCTAssertNotNil(xci!.authenticator)
        
    }
    
    func testBuildXCodeWithDownloader() throws {
        
        // given
        // when
        let xci = try? XCodeInstallBuilder()
            .withDownloader()
            .build()
        
        // then
        XCTAssertNotNil(xci)
        XCTAssertNotNil(xci!.downloader)
        
    }
    
    func testBuildXCodeWithInstaller() throws {
        
        // given
        // when
        let xci = try? XCodeInstallBuilder()
            .withInstaller()
            .build()
        
        // then
        XCTAssertNotNil(xci)
        XCTAssertNotNil(xci!.installer)
        
    }
    
    func testBuildXCodeWithSecretsManagerOK() throws {
        
        // given
        // when
        let xci = try? XCodeInstallBuilder()
            .withDownloader()
            .build()
        
        // then
        XCTAssertNotNil(xci)
        XCTAssertNotNil(xci!.secretsManager)
    }
    
}
