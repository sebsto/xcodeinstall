//
//  File.swift
//  xcodeinstall
//
//  Created by Stormacq, Sebastien on 17/05/2025.
//

import Foundation

extension Collection where Element: Sendable {
    func asyncMap<T: Sendable>(
        _ transform: @Sendable @escaping (Element) async throws -> T
    ) async rethrows -> [T] {
        try await withThrowingTaskGroup(of: (Int, T).self) { group in
            for (index, element) in enumerated() {
                group.addTask {
                    (index, try await transform(element))
                }
            }
            
            var results = Array<T?>(repeating: nil, count: count)
            for try await (index, value) in group {
                results[index] = value
            }
            
            return results.compactMap { $0 }
        }
    }
}
