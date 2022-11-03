//
//  File.swift
//  
//
//  Created by Stormacq, Sebastien on 22/10/2022.
//

import Foundation

// global environment
// var to allow to replace it with a mock
var env = Environment()

// lightweigth dependency injection for testing
struct Environment {
    var api = NetworkAPI()
}

