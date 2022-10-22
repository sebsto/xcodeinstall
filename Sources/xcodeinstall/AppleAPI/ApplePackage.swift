//
//  Package.swift
//  
//
//  Created by Stormacq, Sebastien on 22/10/2022.
//

import Foundation

enum Download : String {
    case xCode = "Xcode"
    case commandLineTools = "Command_Line_Tools_for_Xcode"
}
struct Package: Equatable {

    let download : Download
    let version  : String
    init(download: Download, version: String) {
        self.download = download
        self.version = version
    }
    
    var path : String {
        return "/Developer_Tools/\(packageName)/\(fileName)"
    }
    
    private var packageName : String {
        return "\(download.rawValue)_\(version)"
    }
    
    private var fileName : String {
        switch download {
        case .xCode:
            return "\(download.rawValue)_\(version).xip"
        case .commandLineTools:
            return "\(download.rawValue)_\(version).dmg"
        }
    }
}
