//
//  CLIProgressBar.swift
//  xcodeinstall
//
//  Created by Stormacq, Sebastien on 10/08/2022.
//

// found here https://www.fivestars.blog/articles/ultimate-guide-swift-executables/ and
// https://www.fivestars.blog/articles/executables-progress/

// alternatives to consider to reduce size of dependencies
// https://github.com/vapor/console-kit/tree/main/Sources/ConsoleKit/Activity
// https://github.com/nsscreencast/469-swift-command-line-progress-bar
// https://github.com/jkandzi/Progress.swift/blob/master/Sources/Progress.swift

import Foundation
import CLIlib

struct CLIProgressBar: ProgressUpdateProtocol {

    private let progressAnimation: ProgressUpdateProtocol
    private let stream: OutputBuffer = FileHandle.standardOutput
    private let message: String

    init(animationType: ProgressBarType, message: String) {
        self.message = message
        self.progressAnimation = ProgressBar(output: stream, progressBarType: animationType, title: self.message)
    }

    /// Update the animation with a new step.
    /// - Parameters:
    ///   - step: The index of the operation's current step.
    ///   - total: The total number of steps before the operation is complete.
    ///   - text: The description of the current step.
    func update(step: Int, total: Int, text: String) {
        self.progressAnimation.update(step: step, total: total, text: text)
    }

    /// Complete the animation.
    /// - Parameters:
    ///   - success: Defines if the operation the animation represents was succesful.
    func complete(success: Bool) {
        self.progressAnimation.complete(success: success)
    }

    /// Clear the animation.
    func clear() {
        self.progressAnimation.clear()

    }

}
