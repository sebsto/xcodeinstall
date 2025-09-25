//
//  InstallSupportedFiles.swift
//  xcodeinstall
//
//  Created by Stormacq, Sebastien on 28/08/2022.
//

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif 

enum SupportedInstallation {
    case xCode
    case xCodeCommandLineTools
    case unsuported

    static func supported(_ file: String) -> SupportedInstallation {

        // generic method to test file type

        struct SupportedFiles {
            // the start of the file names we currently support for installtion
            static let packages = ["Xcode", "Command Line Tools for Xcode"]

            // the file extensions of the the file names we currently support for installation
            static let extensions = ["xip", "dmg"]

            // the return values for this function
            static let values: [SupportedInstallation] = [.xCode, .xCodeCommandLineTools]

            static func enumerated() -> EnumeratedSequence<[String]> {
                assert(packages.count == extensions.count)
                assert(packages.count == values.count)
                return packages.enumerated()
            }
        }

        // first return a [SupportedInstallation] with either unsupported or installation type
        let tempResult: [SupportedInstallation] = SupportedFiles.enumerated().compactMap {
            (index, filePrefix) in
            if file.hasPrefix(filePrefix) && file.hasSuffix(SupportedFiles.extensions[index]) {
                return SupportedFiles.values[index]
            } else {
                return SupportedInstallation.unsuported
            }
        }

        // then remove all unsupported values
        let result: [SupportedInstallation] = tempResult.filter { installationType in
            return installationType != .unsuported
        }

        // at this stage we should have 0 or 1 value left
        assert(result.count == 0 || result.count == 1)
        return result.count == 0 ? .unsuported : result[0]

        // non generic method to test the file type

        //        if file.hasPrefix("Command Line Tools for Xcode") && file.hasSuffix(".dmg") {
        //            result = .xCodeCommandLineTools
        //        } else if file.hasPrefix("Xcode") && file.hasSuffix(".xip") {
        //            result = .xCode
        //        } else {
        //            result = .unsuported
        //        }

        //        return result
    }
}
