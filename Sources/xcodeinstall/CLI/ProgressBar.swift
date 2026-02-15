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

// MARK: - OutputBuffer (from CLIlib/progressbar/OutputBuffer.swift)

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

        // Combine \r + text into a single write to avoid recursive calls
        var payload = Data()
        payload.append(0x0D)  // \r — carriage return to beginning of line
        payload.append(textData)
        self.write(payload)
    }

    func clear() {
        guard let data = "\u{001B}[2K\r".data(using: .utf8) else { return }
        self.write(data)
    }
}

// MARK: - ProgressUpdateProtocol & ProgressBarType (from CLIlib/progressbar/ProgressBar.swift)

@MainActor
protocol ProgressUpdateProtocol {
    /// Update the animation with a new step.
    func update(step: Int, total: Int, text: String)

    /// Complete the animation.
    func complete(success: Bool)

    /// Clear the animation.
    func clear()
}

enum ProgressBarType {
    // 30% [============--------------------]
    case percentProgressAnimation

    // [ 1/2 ]
    case countingProgressAnimation

    // [ 1/2 ]
    // [ 2/2 ]
    case countingProgressAnimationMultiLine
}

// MARK: - ProgressBar (from CLIlib/progressbar/ProgressBar.swift)

@MainActor
class ProgressBar: ProgressUpdateProtocol {

    private let progressBarType: ProgressBarType
    private var output: OutputBuffer
    private let title: String?
    private var titlePrinted = false

    private let bold = "\u{001B}[1m"
    private let blue = "\u{001B}[0;34m"
    private let reset = "\u{001B}[0;0m"

    var width: Int = 60
    var fullSign: String = "="
    var emptySign: String = "-"

    init(output: OutputBuffer, progressBarType: ProgressBarType, title: String? = nil) {
        self.output = output
        self.progressBarType = progressBarType
        self.title = title
    }

    func update(step: Int, total: Int, text: String = "") {

        if (!titlePrinted), let title {
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
        let bars = fullSign * numberOfBars
        let ticks = emptySign * numberOfTicks

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
            let prefix = " " * ((numberOfSpaces / 2) + "99% [".count)
            output.write("\(prefix)\(blue)\(bold)\(title)\(reset)\n")

        default:
            output.write("\(blue)\(bold)\(title)\(reset)\n")
        }

        self.titlePrinted = true
    }
}

extension String {
    static func * (char: String, count: Int) -> String {
        var str = ""
        for _ in 0..<count {
            str.append(char)
        }
        return str
    }
}

// MARK: - CLIProgressBar (moved from CLI-driver/CLIProgressBar.swift)

protocol CLIProgressBarProtocol: ProgressUpdateProtocol {
    func define(animationType: ProgressBarType, message: String)
}

class CLIProgressBar: CLIProgressBarProtocol {

    private var progressAnimation: ProgressUpdateProtocol?
    private var message: String?
    private let stream: OutputBuffer = FileHandle.standardOutput

    func define(animationType: ProgressBarType, message: String) {
        self.message = message
        self.progressAnimation = ProgressBar(
            output: stream,
            progressBarType: animationType,
            title: self.message
        )
    }

    func update(step: Int, total: Int, text: String) {
        self.progressAnimation?.update(step: step, total: total, text: text)
    }

    func complete(success: Bool) {
        self.progressAnimation?.complete(success: success)
    }

    func clear() {
        self.progressAnimation?.clear()
    }
}
