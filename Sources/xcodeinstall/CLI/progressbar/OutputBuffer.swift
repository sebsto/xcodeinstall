//
//  OutputBuffer.swift
//  xcodeinstall
//
//  Created by Stormacq, Sebastien on 13/09/2022.
//

import Foundation

protocol OutputBuffer {
    func write(_ text: String)
    func clear()
}

class StringBuffer: OutputBuffer {
    public private(set) var string: String = ""

    public func write(_ text: String) {
        string.append(text)
    }

    public func clear() {
        string = ""
    }
}

extension FileHandle: OutputBuffer {

    public func write(_ text: String) {
        guard let data = text.data(using: .utf8) else { return }

        let backslashR = "\r".data(using: .utf8)!

        write(backslashR)
        write(data)
    }

    public func clear() {
        let clearLineString = "\u{001B}[2K \r"
        write(clearLineString)
    }
}
