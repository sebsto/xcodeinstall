//
//  DispatchSemaphore.swift
//  xcodeinstall
//
//  Created by Stormacq, Sebastien on 21/08/2022.
//

import Foundation

// abstract protocol for testing
protocol DispatchSemaphoreProtocol {
    func wait()
    func signal() -> Int
}
extension DispatchSemaphore: DispatchSemaphoreProtocol {}
