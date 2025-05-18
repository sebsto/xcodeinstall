//
//  DispatchSemaphore.swift
//  xcodeinstall
//
//  Created by Stormacq, Sebastien on 21/08/2022.
//

import Foundation

// abstract protocol for testing
@MainActor
protocol DispatchSemaphoreProtocol: Sendable {
    func wait()
    func signal() -> Int
}
extension DispatchSemaphore: DispatchSemaphoreProtocol {}
