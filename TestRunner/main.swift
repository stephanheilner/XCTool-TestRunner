//
//  main.swift
//  TestRunner
//
//  Created by Stephan Heilner on 12/4/15.
//  Copyright © 2015 The Church of Jesus Christ of Latter-day Saints. All rights reserved.
//

var isValue = false
var arg = ""

for argument in Process.arguments {
    
    if argument.hasPrefix("-") {
        arg = argument
        
        isValue = true
        
    } else if isValue {
        switch arg {
        case "-project":
            Args.shared.project = argument
        case "-workspace":
            Args.shared.workspace = argument
        case "-target":
            Args.shared.target = argument
        case "-partition":
            Args.shared.partition = Int(argument)
        case "-scheme":
            Args.shared.scheme = argument
        case "-partitions-count":
            Args.shared.partitionsCount = Int(argument)
        case "-simulators-count":
            Args.shared.simulatorsCount = Int(argument)
        case "-devices":
            Args.shared.devices = argument
        default:
            print("Unhandled argument", argument)
        }
        
        isValue = false
    }
}

TestRunner().main()