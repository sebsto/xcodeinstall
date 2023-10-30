//
//  InstallDownloadListExtension.swift
//  xcodeinstall
//
//  Created by Stormacq, Sebastien on 29/08/2022.
//

import Foundation

// MARK: Extensions - DownloadList
// not fileprivate to allow testing
extension DownloadList {

    /// Check an entire list for files matching the given filename
    /// This generic function avoids repeating code in the two `find(...)` below
    /// - Parameters
    ///     - fileName: the file name to check (without full path)
    ///     - inList: either a [Download] or a [File]
    ///     - comparison: a function that receives either a `Download` either a `File`
    ///                and returns a `File` when there is a file name match, nil otherwise
    /// - Returns
    ///     a File struct if a file matches, nil otherwise

    private func _find<T: Sequence>(fileName: String, inList list: T, comparison: (T.Element) -> File?) -> File? {

        // first returns an array of File? with nil when filename does not match
        // or file otherwise.
        // for example : [nil, file, nil, nil]
        let result: [File?] = list.compactMap { element -> File? in
            return comparison(element)
        }
        // then remove all nil values
//        .filter { file in
//            return file != nil
//        }

        // we should have 0 or 1 element
        if result.count > 0 {
            assert(result.count == 1)
            return result[0]
        } else {
            return nil
        }

    }

    /// check the entire list of downloads for files matching the given filename
    /// - Parameters
    ///     - fileName: the file name to check (without full path)
    /// - Returns
    ///     a File struct if a file matches, nil otherwise
    func find(fileName: String) -> File? {

        guard let listOfDownloads = self.downloads else {
            return nil
        }

        return _find(fileName: fileName, inList: listOfDownloads, comparison: { element in
            let download = element as Download
            return find(fileName: fileName, inDownload: download)
        })
    }

    // search the list of files ([File]) for an individual file match
    func find(fileName: String, inDownload download: Download) -> File? {

        return _find(fileName: fileName, inList: download.files, comparison: { element in
            let file = element as File
            return file.filename == fileName ? file : nil
        })

    }
}
