//
//  XcodeInstallBuilderTest.swift
//  xcodeinstallTests
//
//  Created by Stormacq, Sebastien on 17/08/2022.
//

import XCTest
@testable import xcodeinstall

class XcodeInstallBuilderTest: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testBuildXCodeWithAuthenticator() throws {
        
        // given
        // when
        let xci = XCodeInstallBuilder()
                    .with(verbosityLevel: .debug)
                    .withAuthenticator()
                    .build()
        
        // then
        XCTAssert(xci.logger.logLevel == .debug)
        XCTAssertNotNil(xci.authenticator)

    }

    func testBuildXCodeWithDownloader() throws {
        
        // given
        // when
        let xci = XCodeInstallBuilder()
                    .with(verbosityLevel: .debug)
                    .withDownloader()
                    .build()
        
        // then
        XCTAssert(xci.logger.logLevel == .debug)
        XCTAssertNotNil(xci.downloader)

    }

    func testBuildXCodeWithInstaller() throws {
        
        // given
        // when
        let xci = XCodeInstallBuilder()
                    .with(verbosityLevel: .debug)
                    .withInstaller()
                    .build()
        
        // then
        XCTAssert(xci.logger.logLevel == .debug)
        XCTAssertNotNil(xci.installer)

    }

}
