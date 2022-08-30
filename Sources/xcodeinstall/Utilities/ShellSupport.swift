//
//  ShellSupport.swift
//  xcodeinstall
//
//  Created by Stormacq, Sebastien on 20/08/2022.
//
//  inspired by https://github.com/kareman/SwiftShell
//  available under MIT License (see below)
//

import Foundation

// MARK: FileHandle

extension FileHandle {

    /// Reads what is available, as a String.
    /// - Parameter encoding: the encoding to use.
    /// - Returns: The contents as a String, or nil the end has been reached.
    public func readAvailable(encoding: String.Encoding) -> String? {
        let data = self.availableData

        guard !data.isEmpty else { return nil }

        guard let result = String(data: data, encoding: encoding) else {
            fatalError("Could not convert binary data to text.")
        }

        return result
    }
}

// MARK: ReadableStream

/// A stream of text.
// protocol allows to abstract stream implementation during testing
protocol ReadableStream: AnyObject, TextOutputStreamable {

    var encoding: String.Encoding { get set }
    var filehandle: FileHandle { get }

    /// All the text the stream contains so far.
    /// If the source is a file this will read everything at once.
    /// If the stream is empty and still open this will wait for more content or end-of-file.
    /// - Returns: more text from the stream, or nil if we have reached the end.
    func readAvailable() -> String?

}

// provides a default implementation for the protocol
// https://docs.swift.org/swift-book/LanguageGuide/Protocols.html#ID521
extension ReadableStream {

    public func readAvailable() -> String? {
        filehandle.readAvailable(encoding: encoding)
    }

    /// Writes the text in this stream to the given TextOutputStream.
    public func write<Target: TextOutputStream>(to target: inout Target) {
        while let text = self.readAvailable() {
            target.write(text)
        }
    }
}

// add the possibility to register handlers when data are available
extension ReadableStream {

    /// Sets code to be executed whenever there is new output available.
    /// - Note: if the stream is read from outside of `handler`, or more than once inside
    /// it, it may be called once when stream is closed and empty.
    private func onOutput(_ handler: @escaping (ReadableStream?) -> Void) {
        self.filehandle.readabilityHandler = { [weak self] _  in
            handler(self)
        }
    }

    /// Sets code to be executed whenever there is new text output available.
    /// - Note: if the stream is read from outside of `handler`, or more than once inside
    /// it, it may be called once when stream is closed and empty.
    func onStringOutput(_ handler: @escaping (String) -> Void) {
        self.onOutput { stream in
            if let output = stream?.readAvailable() {
                handler(output)
            }
        }
    }
}

// MARK: Implementation

// the stream used by Shell to use as stdOut and stdErr of the process we launch
public class FileHandleStream: ReadableStream {

    public let filehandle: FileHandle
    public var encoding: String.Encoding

    public init(_ filehandle: FileHandle, encoding: String.Encoding = String.Encoding.utf8) {
        self.filehandle = filehandle
        self.encoding = encoding
    }
}

/*
The MIT License (MIT)

Copyright (c) 2014 Kåre Morstøl, NotTooBad Software (nottoobadsoftware.com)

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
 */
