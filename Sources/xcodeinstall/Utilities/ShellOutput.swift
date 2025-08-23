//
//  File.swift
//  xcodeinstall
//
//  Created by Stormacq, Sebastien on 16/05/2025.
//

import Subprocess

#if canImport(System)
import System
#else
import SystemPackage
#endif

typealias ShellOutput = CollectedResult<StringOutput<Unicode.UTF8>, StringOutput<Unicode.UTF8>>

extension Executable {
    public static func path(_ path: String) -> Self {
        Executable.path(FilePath(path))
    }
}
