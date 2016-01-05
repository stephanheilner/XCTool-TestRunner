//
//  TestRunnerOperation.swift
//  TestRunner
//
//  Created by Stephan Heilner on 1/5/16.
//  Copyright © 2016 The Church of Jesus Christ of Latter-day Saints. All rights reserved.
//

import Foundation

enum TestRunnerStatus: Int {
    case Stopped
    case Running
    case Success
    case Failed
}

class TestRunnerOperation: NSOperation {
    
    private let deviceID: String
    private let tests: [String]

    override var executing : Bool {
        get {
            return _executing
        }
        set {
            willChangeValueForKey("isExecuting")
            _executing = newValue
            didChangeValueForKey("isExecuting")
        }
    }
    private var _executing : Bool
    
    override var finished : Bool {
        get {
            return _finished
        }
        set {
            willChangeValueForKey("isFinished")
            _finished = newValue
            didChangeValueForKey("isFinished")
        }
    }
    private var _finished : Bool
    
    var startTime: NSTimeInterval?
    var elapsedTime: NSTimeInterval?
    
    var standardOutputData = [NSData]()
    var standardErrorData = [NSData]()
    var status: TestRunnerStatus = .Stopped
    
    init(deviceID: String, tests: [String]) {
        self.deviceID = deviceID
        self.tests = tests
        
        _executing = false
        _finished = false
        
        super.init()
    }
    
    override func start() {
        super.start()
        
        _executing = true
        
        status = .Running
        startTime = NSDate().timeIntervalSince1970

        defer {
            if let startTime = startTime {
                self.elapsedTime = NSDate(timeIntervalSinceReferenceDate: startTime).timeIntervalSince1970

                _executing = false
                _finished = true
            }
        }
        
        guard let target = Args.shared.target, scheme = Args.shared.scheme else { return }
        
        let onlyTests: String = "\(target):" + tests.joinWithSeparator(",")
        
        var arguments = [String]()
        
        if let project = Args.shared.project {
            arguments += ["-project", project]
        } else if let workspace = Args.shared.workspace {
            arguments += ["-workspace", workspace]
        }
        arguments += ["-scheme", scheme, "-sdk", "iphonesimulator8.4", "-destination", "id=\(deviceID)", "run-tests", "-newSimulatorInstance", "-only", onlyTests, "-reporter", "plain"]
        
        let task = NSTask()
        task.launchPath = Args.xctool
        task.arguments = arguments
        
        let standardOutput = NSPipe()
        task.standardOutput = standardOutput
        standardOutput.fileHandleForReading.readabilityHandler = { handle in
            self.standardOutputData.append(handle.availableData)
        }

        let standardError = NSPipe()
        task.standardError = standardError
        standardError.fileHandleForReading.readabilityHandler = { handle in
            self.standardErrorData.append(handle.availableData)
        }
        
        task.terminationHandler = { task in
            self.status = task.terminationStatus == 0 ? .Success : .Failed
        }
        
        task.launch()
        task.waitUntilExit()

        print("Errors:", deviceID)
        for data in standardErrorData {
            if let errorLog = String(data: data, encoding: NSUTF8StringEncoding) {
                print(errorLog)
            }
        }
        
        print("Output:", deviceID)
        for data in standardOutputData {
            if let outputLog = String(data: data, encoding: NSUTF8StringEncoding) {
                print(outputLog)
            }
        }
    }
    
}
