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
            guard let password = getpass(prompt) else {
                return nil
            }
            return String(cString: password)
        } else {
            print(prompt, terminator: "")
            return Swift.readLine()
        }
    }
}
