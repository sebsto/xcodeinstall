//
//  NooraReadLine.swift
//  xcodeinstall
//
//  Noora-backed ReadLineProtocol implementation
//

import Noora

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

final class NooraReadLine: ReadLineProtocol {
    func readLine(prompt: String, silent: Bool) -> String? {
        if silent {
            return String(cString: getpass(prompt))
        } else {
            print(prompt, terminator: "")
            return Swift.readLine()
        }
    }
}
