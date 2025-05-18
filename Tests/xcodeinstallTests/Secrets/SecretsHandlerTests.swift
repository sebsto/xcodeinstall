//
//  FileSecretHandlerTest.swift
//  xcodeinstallTests
//
//  Created by Stormacq, Sebastien on 05/08/2022.
//

import Testing

@testable import xcodeinstall

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

protocol SecretsHandlerTestsProtocol {
    func testMergeCookiesNoConflict() async throws
    func testMergeCookiesOneConflict() async throws
    func testLoadAndSaveSession() async throws
    func testLoadAndSaveCookies() async throws
    func testLoadSessionNoExist() async
}

struct SecretsHandlerTestsBase<T: SecretsHandlerProtocol> {

    var secrets: T?

    // 4 cookies : dslang site, myacinfo, aasp
    private let cookieStringOne =
        "dslang=GB-EN; Domain=apple.com; Path=/; Secure; HttpOnly, site=GBR; Domain=apple.com; Path=/; Secure; HttpOnly, myacinfo=DAW47V3; Domain=apple.com; Path=/; Secure; HttpOnly, aasp=1AD6CF2; Domain=idmsa.apple.com; Path=/; Secure; HttpOnly%"

    // 2 cookies : DSESSIONID, ADCDownloadAuth
    private let cookieStringTwo =
        "DSESSIONID=150f81k3; Path=/; Domain=developer.apple.com; Secure; HttpOnly, ADCDownloadAuth=qMa%0D%0A;Version=1;Comment=;Domain=apple.com;Path=/;Max-Age=108000;Secure;HttpOnly;Expires=Fri, 05 Aug 2022 11:58:50 GMT"

    // 1 cookie : dslang  conflict with string one
    private let cookieStringConflict = "dslang=FR-FR; Domain=apple.com; Path=/; Secure; HttpOnly"

    func testMergeCookiesNoConflict() async throws {

        // given

        // create a cookie file
        _ = try await self.secrets!.saveCookies(cookieStringOne)

        // when

        // merge with second set of cookies
        _ = try await self.secrets!.saveCookies(cookieStringTwo)

        // then

        // new file must be the merged results of the two set of cookies.
        let cookies = try await self.secrets!.loadCookies()

        // number of cookie is the sum of the two files
        #expect(cookies.count == 6)

        // cookies from second file are present with correct values
        #expect(cookies.contains(where: { c in c.name == "ADCDownloadAuth" }))
        #expect(cookies.contains(where: { c in c.name == "DSESSIONID" }))
    }

    func testMergeCookiesOneConflict() async throws {

        // given
        // create a cookie file
        _ = try await self.secrets!.saveCookies(cookieStringOne)

        // when

        // merge with second set of cookies
        _ = try await self.secrets!.saveCookies(cookieStringConflict)

        // then

        // new file must be the merged results of the two set of cookies.
        let cookies = try await self.secrets!.loadCookies()

        // number of cookie is the original count (conflicted cookie is not added, but merged)
        #expect(cookies.count == 4)

        // cookies from second file is present
        #expect(cookies.contains(where: { c in c.name == "dslang" }))

        // with correct values
        let c = cookies.first(where: { c in c.name == "dslang" && c.value == "FR-FR" })
        #expect(c != nil)
    }

    func testLoadAndSaveSession() async throws {

        do {
            // given
            let session = AppleSession(
                itcServiceKey: AppleServiceKey(authServiceUrl: "authServiceUrl", authServiceKey: "authServiceKey"),
                xAppleIdSessionId: "xAppleIdSessionId",
                scnt: "scnt"
            )

            // when
            let _ = try await secrets!.saveSession(session)
            let newSession = try await secrets!.loadSession()

            // then
            #expect(session == newSession)

        } catch {
            Issue.record("Unexpected exception while testing : \(error)")
        }
    }

    func testLoadAndSaveCookies() async throws {

        // given

        // create a cookie file
        _ = try await self.secrets!.saveCookies(cookieStringOne)

        // when

        // reading cookies
        let cookies = try await self.secrets!.loadCookies()

        // then

        // number of cookie is equal the orginal string
        #expect(cookies.count == 4)

        // cookies are present with correct values
        #expect(cookies.contains(where: { c in c.name == "dslang" }))
        #expect(cookies.contains(where: { c in c.name == "site" }))
        #expect(cookies.contains(where: { c in c.name == "myacinfo" }))
        #expect(cookies.contains(where: { c in c.name == "aasp" }))
    }

    func testLoadSessionNoExist() async {

        // given
        // no session exist (clear session happened as setup time)

        // when
        let newSession = try? await secrets!.loadSession()

        // then
        #expect(newSession == nil)

    }
}
