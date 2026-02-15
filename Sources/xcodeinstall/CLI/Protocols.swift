//
//  Protocols.swift
//  xcodeinstall
//
//  Migrated from CLIlib — local protocol definitions
//

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

// MARK: - Display

enum DisplayStyle {
    case normal
    case success
    case error(nextSteps: [String] = [])
    case warning
    case info
}

@MainActor
protocol DisplayProtocol: Sendable {
    func display(_ msg: String, terminator: String, style: DisplayStyle)
}

extension DisplayProtocol {
    func display(_ msg: String, terminator: String = "\n") {
        display(msg, terminator: terminator, style: .normal)
    }
    func display(_ msg: String, style: DisplayStyle) {
        display(msg, terminator: "\n", style: style)
    }
}

// MARK: - ReadLine

@MainActor
protocol ReadLineProtocol: Sendable {
    func readLine(prompt: String, silent: Bool) -> String?
}
