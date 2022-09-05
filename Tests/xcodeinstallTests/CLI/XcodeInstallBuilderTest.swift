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
        let xci = try? XCodeInstallBuilder()
            .with(verbosityLevel: .debug)
            .withAuthenticator()
            .build()
        
        // then
        XCTAssertNotNil(xci)
        XCTAssert(xci!.logger.logLevel == .debug)
        XCTAssertNotNil(xci!.authenticator)
        
    }
    
    func testBuildXCodeWithDownloader() throws {
        
        // given
        // when
        let xci = try? XCodeInstallBuilder()
            .with(verbosityLevel: .debug)
            .withDownloader()
            .build()
        
        // then
        XCTAssertNotNil(xci)
        XCTAssert(xci!.logger.logLevel == .debug)
        XCTAssertNotNil(xci!.downloader)
        
    }
    
    func testBuildXCodeWithInstaller() throws {
        
        // given
        // when
        let xci = try? XCodeInstallBuilder()
            .with(verbosityLevel: .debug)
            .withInstaller()
            .build()
        
        // then
        XCTAssertNotNil(xci)
        XCTAssert(xci!.logger.logLevel == .debug)
        XCTAssertNotNil(xci!.installer)
        
    }
    
    func testBuildXCodeWithSecretsManagerOK() throws {
        
        // given
        // when
        let xci = try? XCodeInstallBuilder()
            .with(verbosityLevel: .debug)
            .withAWSSecretsManager(region: "us-east-1")
            .withDownloader()
            .build()
        
        // then
        XCTAssertNotNil(xci)
        XCTAssert(xci!.logger.logLevel == .debug)
        XCTAssertNotNil(xci!.secretsManager)
        let asm = xci!.secretsManager as? AWSSecretsHandler
        XCTAssertNotNil(asm)
        
    }
    
    func testBuildXCodeWithSecretsManagerNotOK() throws {
        
        // given
        // when
        do {
            let _ = try XCodeInstallBuilder()
                .with(verbosityLevel: .debug)
                .withAWSSecretsManager(region: "xxx")
                .withDownloader()
                .build()
            
            // then
            XCTAssert(false, "expected to throw an error")
        } catch SecretsHandlerError.invalidRegion(let region){
            //expected
            XCTAssertEqual(region, "xxx")
        } catch {
            // no other error are thrown
            XCTAssert(false)
        }
        
    }
    
    
}
