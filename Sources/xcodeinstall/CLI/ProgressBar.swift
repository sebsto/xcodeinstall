//
//  ProgressBar.swift
//  xcodeinstall
//
//  Internalized from CLIlib — progress bar infrastructure
//

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

// MARK: - OutputBuffer

protocol OutputBuffer {
    func write(_ text: String)
    func clear()
}

class StringBuffer: OutputBuffer {
    private(set) var string: String = ""

    func write(_ text: String) {
        string.append(text)
    }

    func clear() {
        string = ""
    }
}

extension FileHandle: OutputBuffer {

    func write(_ text: String) {
        guard let textData = text.data(using: .utf8) else { return }

        var payload = Data()
        payload.append(0x0D)
        payload.append(textData)
        self.write(payload)
    }

    func clear() {
        guard let data = "\u{001B}[2K\r".data(using: .utf8) else { return }
        self.write(data)
    }
}

// MARK: - ProgressBarType

enum ProgressBarType {
    case percentProgressAnimation
    case countingProgressAnimation
    case countingProgressAnimationMultiLine
}

// MARK: - ProgressBarProtocol (single unified protocol)

@MainActor
protocol ProgressBarProtocol {
    func define(animationType: ProgressBarType, message: String)
    func update(step: Int, total: Int, text: String)
    func complete(success: Bool)
    func clear()
}

// MARK: - ProgressBar (single concrete implementation)

@MainActor
class ProgressBar: ProgressBarProtocol {

    private let output: OutputBuffer
    private var progressBarType: ProgressBarType = .percentProgressAnimation
    private var title: String?
    private var titlePrinted = false

    private let bold = "\u{001B}[1m"
    private let blue = "\u{001B}[0;34m"
    private let reset = "\u{001B}[0;0m"

    var width: Int = 60
    var fullSign: String = "="
    var emptySign: String = "-"

    init(output: OutputBuffer = FileHandle.standardOutput) {
        self.output = output
    }

    func define(animationType: ProgressBarType, message: String) {
        self.progressBarType = animationType
        self.title = message
        self.titlePrinted = false
    }

    func update(step: Int, total: Int, text: String = "") {

        if !titlePrinted, let title {
            printTitle(title)
        }

        switch self.progressBarType {
        case .percentProgressAnimation:
            percentProgress(step: step, total: total, text: text)

        case .countingProgressAnimation:
            countingProgress(step: step, total: total, text: text)

        case .countingProgressAnimationMultiLine:
            countingProgressMultiLine(step: step, total: total, text: text)
        }
    }

    func clear() {
        output.clear()

        if titlePrinted {
            output.write("\u{001B}[1A")
            output.clear()
        }
    }

    func complete(success: Bool) {
        if success {
            output.write("[ OK ]\n")
        } else {
            output.write("[ Error ]\n")
        }
    }

    private func percentProgress(step: Int, total: Int, text: String = "") {
        let progress = Float(step) / Float(total)
        let numberOfBars = Int(floor(progress * Float(width)))
        let numberOfTicks = width - numberOfBars
        let bars = String(repeating: fullSign, count: numberOfBars)
        let ticks = String(repeating: emptySign, count: numberOfTicks)

        let percentage = Int(floor(progress * 100))
        var string = ""
        string += "\(percentage)% "
        string += "[\(bars)\(ticks)]"
        if text.count > 0 {
            string += " \(text)"
        }
        output.write(string)

        if step >= total {
            output.write("\n")
        }
    }

    private func countingProgress(step: Int, total: Int, text: String = "") {
        output.clear()
        output.write("[\(step)/\(total)] \(text)")
        if step >= total {
            output.write("\n")
        }
    }

    private func countingProgressMultiLine(step: Int, total: Int, text: String = "") {
        output.write("[\(step)/\(total)] \(text)\n")
    }

    private func printTitle(_ title: String) {

        switch self.progressBarType {
        case .percentProgressAnimation:
            let numberOfSpaces = self.width - title.count
            let prefix = String(repeating: " ", count: (numberOfSpaces / 2) + "99% [".count)
            output.write("\(prefix)\(blue)\(bold)\(title)\(reset)\n")

        default:
            output.write("\(blue)\(bold)\(title)\(reset)\n")
        }

        self.titlePrinted = true
    }
}

