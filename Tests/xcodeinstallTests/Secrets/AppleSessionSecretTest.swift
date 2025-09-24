//
//  AppleSessionSecretTest.swift
//  xcodeinstallTests
//
//  Created by Stormacq, Sebastien on 15/09/2022.
//

import Testing

@testable import xcodeinstall

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
struct AppleSessionSecretTest {

    @Test("Test From String")
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
        #expect(ass != nil)

        let c = ass?.cookies()
        #expect(c?.count == 2)

        let s = ass?.session
        #expect(s != nil)
    }

    @Test("Test From Object")
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
        #expect(c.count == 2)

        let _ = #expect(throws: Never.self) {
            try ass.string()
        }
        if let a = try? ass.string() {
            #expect(a.contains("scnt12345"))
        } else {
            Issue.record("Failed to get string representation")
        }
    }

}
