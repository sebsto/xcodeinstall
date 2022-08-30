//
//  InstallStringExtension.swift
//  xcodeinstall
//
//  Created by Stormacq, Sebastien on 29/08/2022.
//

import Foundation

// MARK: Extensions - String
extension String {

    /// assume the string represents a full file path, it extracts the file name from the full path
    /// - returns the part of the string which is after the last /
    func fileName() -> String {
        guard let lastSlashIndex = self.lastIndex(of: "/") else {
            let errorMessage = "Can not find last slash in \(self)"
            fatalError(errorMessage) // this is a programming error
        }
        let index = self.index(after: lastSlashIndex)
        return String(self[index...])
    }
}
