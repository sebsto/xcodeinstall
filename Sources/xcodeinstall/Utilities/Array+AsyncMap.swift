//
//  File.swift
//  xcodeinstall
//
//  Created by Stormacq, Sebastien on 17/05/2025.
//

import Foundation

extension Array {
    func asyncMap<T>(_ transform: @Sendable (Element) async throws -> T) async rethrows -> [T] {
        var results = [T]()
        for element in self {
            try await results.append(transform(element))
        }
        return results
    }
}
