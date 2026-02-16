//
//  ListTest.swift
//  xcodeinstallTests
//
//  Created by Stormacq, Sebastien on 22/08/2022.
//

import Foundation
import Testing

@testable import xcodeinstall

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

#if canImport(FoundationEssentials)
import FoundationEssentials
#endif

extension DownloadTests {

    @Test("Test list no force")
    func testListNoForce() async throws {

        // given
        let downloader = env.downloader

        // when
        let (result, source): (DownloadList?, ListSource) = try await downloader.list(force: false)

        // then
        #expect(result != nil)
        #expect(result?.downloads != nil)
        #expect(result!.downloads!.count > 0)
        #expect(source == .cache)
    }

    @Test("Test list force")
    func testListForce() async throws {
        let _ = await #expect(throws: Never.self) {
            // given
            let listData = try loadTestData(file: .downloadList)
            let list = try JSONDecoder().decode(DownloadList.self, from: listData)
            self.env.downloader.nextListResult = list
            self.env.downloader.nextListSource = .network

            // when
            let downloader = self.env.downloader
            let (result, source) = try await downloader.list(force: true)

            // then
            #expect(result.downloads != nil)
            #expect(result.downloads!.count == 1127)
            #expect(source == .network)
        }
    }

    @Test(
        "Test list force with parsing error"
        //   ,.enabled(if: false)
    )
    func testListForceParsingError() async throws {

        let error = await #expect(throws: DownloadError.self) {

            // given
            self.env.downloader.nextListError = DownloadError.parsingError(error: nil)

            // when
            let downloader = self.env.downloader
            let _ = try await downloader.list(force: true)

            // then
            // an exception must be thrown

        }
        #expect(error == DownloadError.parsingError(error: nil))
    }

    @Test("Test list force with authentication error")
    func testListForceAuthenticationError() async throws {

        let error = await #expect(throws: DownloadError.self) {

            // given
            self.env.downloader.nextListError = DownloadError.authenticationRequired

            // when
            let downloader = self.env.downloader
            let _ = try await downloader.list(force: true)

            // then
            //an exception must be thrown

        }
        #expect(error == DownloadError.authenticationRequired)
    }

    @Test("Test list force with unknown error")
    func testListForceUnknownError() async throws {

        let error = await #expect(throws: DownloadError.self) {

            // given
            self.env.downloader.nextListError = DownloadError.unknownError(
                errorCode: 9999, errorMessage: "Unknown error"
            )

            // when
            let downloader = self.env.downloader
            let _ = try await downloader.list(force: true)

            // then
            //an exception must be thrown

        }
        #expect(error == DownloadError.unknownError(errorCode: 9999, errorMessage: "Unknown error"))
    }

    @Test("Test list force with non 200 code")
    func testListForceNon200Code() async throws {

        let error = await #expect(throws: DownloadError.self) {

            // given
            self.env.downloader.nextListError = DownloadError.invalidResponse

            // when
            let downloader = self.env.downloader
            let _ = try await downloader.list(force: true)

            // then
            //an exception must be thrown

        }

        #expect(error == DownloadError.invalidResponse)
    }

    @Test("Test list force with no cookies")
    func testListForceNoCookies() async throws {

        let error = await #expect(throws: DownloadError.self) {

            // given
            self.env.downloader.nextListError = DownloadError.invalidResponse

            // when
            let downloader = self.env.downloader
            let _ = try await downloader.list(force: true)

            // then
            //an exception must be thrown

        }

        #expect(error == DownloadError.invalidResponse)
    }

    @Test("Test list force with account needs upgrade")
    func testAccountNeedsUpgrade() async {

        let error = await #expect(throws: DownloadError.self) {
            // given
            self.env.downloader.nextListError = DownloadError.accountNeedUpgrade(
                errorCode: 2170,
                errorMessage:
                    "Your developer account needs to be updated.  Please visit Apple Developer Registration."
            )

            // when
            let downloader = self.env.downloader
            let _ = try await downloader.list(force: true)

            // then
            //an exception must be thrown

        }

        #expect(
            error
                == DownloadError.accountNeedUpgrade(
                    errorCode: 2170,
                    errorMessage:
                        "Your developer account needs to be updated.  Please visit Apple Developer Registration."
                )
        )
    }

}
