//
//  Args.swift
//  TestRunner
//
//  Created by Stephan Heilner on 12/4/15.
//  Copyright © 2015 The Church of Jesus Christ of Latter-day Saints. All rights reserved.
//

import Foundation

class Args: NSObject {
    static let shared = Args()
    
    var project: String?
    var workspace: String?
    var scheme: String?
    var target: String?
    var simulatorsCount: Int?
    var partitionsCount: Int?
    var devices: String?
    var partition: Int?
    
    static let xctool = "/Users/stephan/Library/Developer/Xcode/DerivedData/xctool-cdhvupyyazpwxlcktfudmidrzftl/Build/Products/Debug/xctool"
//    static let xctool = "/usr/local/bin/xctool"
}