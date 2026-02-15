//
//  NooraDisplay.swift
//  xcodeinstall
//
//  Noora-backed DisplayProtocol implementation
//

import Noora

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

final class NooraDisplay: DisplayProtocol {
    private let noora = Noora()

    func display(_ msg: String, terminator: String, style: DisplayStyle) {
        switch style {
        case .normal:
            print(msg, terminator: terminator)
        case .success:
            noora.success(SuccessAlert(stringLiteral: msg))
        case .error(let nextSteps):
            if nextSteps.isEmpty {
                noora.error(ErrorAlert(stringLiteral: msg))
            } else {
                let takeaways = nextSteps.map { TerminalText(stringLiteral: $0) }
                noora.error(.alert(TerminalText(stringLiteral: msg), takeaways: takeaways))
            }
        case .warning:
            noora.warning(WarningAlert(stringLiteral: msg))
        case .info:
            noora.info(InfoAlert(stringLiteral: msg))
        case .security:
            print("🔐 \(msg)", terminator: terminator)
        }
    }
}
