//
//  File.swift
//  xcodeinstall
//
//  Created by Stormacq, Sebastien on 16/05/2025.
//

import Subprocess
import System

typealias ShellOutput = CollectedResult<StringOutput<Unicode.UTF8>, DiscardedOutput>

extension Executable {
    public static func path(_ path: String) -> Self {
        Executable.path(FilePath(path))
    }
}
