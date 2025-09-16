//
//  AppleSessionSecretTest.swift
//  xcodeinstallTests
//
//  Created by Stormacq, Sebastien on 15/09/2022.
//

import XCTest

@testable import xcodeinstall

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
@MainActor
final class AppleSessionSecretTest: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testFromString() {

        // given and when
        let ass = try? AppleSessionSecret(
            fromString:
                """
                {
                   "session": {
                      "scnt":"scnt12345",
                      "itcServiceKey": {
                         "authServiceKey":"authServiceKey",
                         "authServiceUrl":"authServiceUrl"
                      },
                      "xAppleIdSessionId":"sessionid"
                   },
                   "rawCookies":"DSESSIONID=150f81k3; Path=/; Domain=developer.apple.com; Secure; HttpOnly, ADCDownloadAuth=qMa%0D%0A;Version=1;Comment=;Domain=apple.com;Path=/;Max-Age=108000;Secure;HttpOnly;Expires=Fri, 05 Aug 2022 11:58:50 GMT"
                }
                """
        )

        // then
        XCTAssertNotNil(ass)

        let c = ass?.cookies()
        XCTAssertEqual(c?.count, 2)

        let s = ass?.session
        XCTAssertNotNil(s)
    }

    func testFromObject() {

        // given
        let cookies =
            "DSESSIONID=150f81k3; Path=/; Domain=developer.apple.com; Secure; HttpOnly, ADCDownloadAuth=qMa%0D%0A;Version=1;Comment=;Domain=apple.com;Path=/;Max-Age=108000;Secure;HttpOnly;Expires=Fri, 05 Aug 2022 11:58:50 GMT"
        let session = AppleSession(
            itcServiceKey: AppleServiceKey(authServiceUrl: "authServiceUrl", authServiceKey: "authServiceKey"),
            xAppleIdSessionId: "sessionid",
            scnt: "scnt12345"
        )

        // when
        let ass = AppleSessionSecret(cookies: cookies, session: session)

        // then
        let c = ass.cookies()
        XCTAssertNotNil(c)
        XCTAssertEqual(c.count, 2)

        XCTAssertNoThrow(try ass.string())
        if let a = try? ass.string() {
            XCTAssertNotNil(a)
            XCTAssertTrue(a.contains("scnt12345"))
        } else {
            XCTAssert(false)
        }
    }

}
