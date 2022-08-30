//
//  FileSecretHandlerTest.swift
//  xcodeinstallTests
//
//  Created by Stormacq, Sebastien on 05/08/2022.
//

import XCTest
@testable import xcodeinstall


class FileSecretHandlerTest: XCTestCase {
    
    var secrets : FileSecretsHandler?
    
    // 4 cookies : dslang site, myacinfo, aasp
    private let cookieStringOne = "dslang=GB-EN; Domain=apple.com; Path=/; Secure; HttpOnly, site=GBR; Domain=apple.com; Path=/; Secure; HttpOnly, myacinfo=DAW47V3; Domain=apple.com; Path=/; Secure; HttpOnly, aasp=1AD6CF2; Domain=idmsa.apple.com; Path=/; Secure; HttpOnly%"
    
    // 2 cookies : DSESSIONID, ADCDownloadAuth
    private let cookieStringTwo = "DSESSIONID=150f81k3; Path=/; Domain=developer.apple.com; Secure; HttpOnly, ADCDownloadAuth=qMa%0D%0A;Version=1;Comment=;Domain=apple.com;Path=/;Max-Age=108000;Secure;HttpOnly;Expires=Fri, 05 Aug 2022 11:58:50 GMT"
    
    // 1 cookie : dslang  conflict with string one
    private let cookieStringConflict = "dslang=FR-FR; Domain=apple.com; Path=/; Secure; HttpOnly"

    override func setUpWithError() throws {
        let log = Log(logLevel: .debug)
        self.secrets = FileSecretsHandler(logger: log.defaultLogger)
        self.secrets!.clearSecrets(preserve: true)
    }

    override func tearDownWithError() throws {
        self.secrets!.restoreSecrets()
    }

    func testMergeCookiesNoConflict() throws {
        
        // given

        // create a cookie file
        _ = try self.secrets!.saveCookies(cookieStringOne)

        // when
        
        // merge with second set of cookies
        _ = try self.secrets!.saveCookies(cookieStringTwo)
        
        // then
        
        // new file must be the merged results of the two set of cookies.
        let cookies = try self.secrets!.loadCookies()
        
        
        // number of cookie is the sum of the two files
        XCTAssert(cookies.count == 6)
        
        // cookies from second file are present with correct values
        XCTAssert(cookies.contains(where: { c in c.name == "ADCDownloadAuth" }))
        XCTAssert(cookies.contains(where: { c in c.name == "DSESSIONID" }))
    }

    func testMergeCookiesOneConflict() throws {
        
        // given
        // create a cookie file
        _ = try self.secrets!.saveCookies(cookieStringOne)

        // when
        
        // merge with second set of cookies
        _ = try self.secrets!.saveCookies(cookieStringConflict)
        
        // then
        
        // new file must be the merged results of the two set of cookies.
        let cookies = try self.secrets!.loadCookies()
        
        
        // number of cookie is the original count (conflicted cookie is not added, but merged)
        XCTAssert(cookies.count == 4)
        
        // cookies from second file is present
        XCTAssert(cookies.contains(where: { c in c.name == "dslang" }))

        // with correct values
        let c = cookies.first(where: { c in c.name == "dslang" && c.value == "FR-FR" })
        XCTAssertNotNil(c)
    }
}
