//
//  CLIProgressBar.swift
//  xcodeinstall
//
//  Created by Stormacq, Sebastien on 10/08/2022.
//

// found here https://www.fivestars.blog/articles/ultimate-guide-swift-executables/ and
// https://www.fivestars.blog/articles/executables-progress/

import Foundation
import TSCBasic
import TSCUtility

// abstract to the progress animation interface
protocol ProgressUpdateProtocol: ProgressAnimationProtocol {}

enum ProgressBarType {
    case percentProgressAnimation
    case countingProgressAnimation
    case countingProgressAnimationMultiLine
}

struct CLIProgressBar: ProgressUpdateProtocol {

    private let progressAnimation: ProgressAnimationProtocol
    private let stream: WritableByteStream
    private let message: String

    init(animationType: ProgressBarType, stream: WritableByteStream, message: String) {
        self.stream  = stream
        self.message = message

        switch animationType {
        case .percentProgressAnimation:
            self.progressAnimation = PercentProgressAnimation(stream: self.stream, header: self.message)
        case .countingProgressAnimation:
            self.progressAnimation = NinjaProgressAnimation(stream: self.stream)
        case .countingProgressAnimationMultiLine:
            self.progressAnimation = MultiLineNinjaProgressAnimation(stream: self.stream)
        }
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
