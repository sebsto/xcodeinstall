//
//  LoggerTest.swift
//  xcodeinstallTests
//
//  Created by Stormacq, Sebastien on 16/08/2022.
//

import XCTest
@testable import xcodeinstall

class LoggerTest: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testLogger() throws {
        
        // given
        // when
        let log = Log(logLevel: .info)
        
        // then
        XCTAssert(log.defaultLogger.logLevel == .info)
        XCTAssert(log.defaultLogger.label == "xcodeinstall")
    }

    func testLoggerSetLevel() throws {
        
        // given
        var log = Log(logLevel: .info)
        
        // when
        log.setLogLevel(level: .trace)
        
        // then
        XCTAssert(log.defaultLogger.logLevel == .trace)
    }

}
