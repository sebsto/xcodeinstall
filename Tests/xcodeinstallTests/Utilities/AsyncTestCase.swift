//
//  AsyncTestCase.swift
//  xcodeinstallTests
//
//  Created by Stormacq, Sebastien on 04/09/2022.
//

import XCTest

class AsyncTestCase: XCTestCase {

    func asyncSetUpWithError() async throws {
    }
    
    func asyncTearDownWithError() async throws {
    }
    
    override func setUpWithError() throws {
        wait {
            try await self.asyncSetUpWithError()
        }
    }
    
    override func tearDownWithError() throws {
        wait {
            try await self.asyncTearDownWithError()
        }
    }
    
    func wait(asyncBlock: @escaping (() async throws -> Void)) {
        let semaphore = DispatchSemaphore(value: 0)
        Task.init {
            do {
                try await asyncBlock()
                semaphore.signal()
            } catch {
                semaphore.signal()
            }
        }
        semaphore.wait()
    }

}
