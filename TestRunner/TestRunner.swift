//
//  main.swift
//  TestRunner
//
//  Created by Stephan Heilner on 12/4/15.
//  Copyright © 2015 The Church of Jesus Christ of Latter-day Saints. All rights reserved.
//

import Foundation

class TestRunner {
    
    var deviceIDs = [String]()
    let testRunnerQueue = NSOperationQueue()
    
    let clean = true
    let build = true
    
    func printLog(thelog: String) {
        print(thelog, terminator: "")
    }
    
    func main() {
        if cleanBuild() && buildTests() {
            let devices = resetAndCreateDevices()
            
            print(devices)
            
            let testsByDeviceID = loadPartitionTestsByDevices(devices)
            
            // Run tests on device ID

            let operations = testsByDeviceID.map { deviceID, tests -> TestRunnerOperation in
                let op = TestRunnerOperation(deviceID: deviceID, tests: tests)
                op.completionBlock = {
                    NSLog("Finished %@", deviceID)
                }
                return op
            }
            testRunnerQueue.addOperations(operations, waitUntilFinished: true)
            testRunnerQueue.waitUntilAllOperationsAreFinished()
            
            NSLog("Finished everything in queue")
        }
    }
    
    func loadPartitionTestsByDevices(devices: [String: [String]]) -> [String: [String]] {
        let tests = listTests()
        if tests.isEmpty { return [:] }
        
        let simulatorsCount = Args.shared.simulatorsCount ?? 1
        let partitionsCount = Args.shared.partitionsCount ?? 1
        let testsPerDeviceIDCount = Int(ceil(Float(tests.count) / Float(simulatorsCount * partitionsCount)))

        let partition = Args.shared.partition ?? 1
        let numTestsPerPartition = testsPerDeviceIDCount * simulatorsCount

        var count = 0
        var startIndex = 0
        
        var testsByDeviceID = [String: [String]]()
        for (_, deviceIDs) in devices {
            count = 0
            startIndex = numTestsPerPartition * (partition - 1)
            let endIndex = numTestsPerPartition * partition
            
            for deviceID in deviceIDs {
                count = 0
                
                for (index, test) in tests.enumerate() {
                    if index >= startIndex && index < endIndex {
                        count++

                        if var deviceTests = testsByDeviceID[deviceID] {
                            deviceTests.append(test)
                            testsByDeviceID[deviceID] = deviceTests
                        } else {
                            testsByDeviceID[deviceID] = [test]
                        }
                        startIndex = (index + 1)
                        
                        if count >= testsPerDeviceIDCount {
                            count = 0
                            break
                        }
                    }
                }
            }
        }
        
        return testsByDeviceID
    }
    
    func listTests() -> [String] {
        var tests = [String]()
        
        if let scheme = Args.shared.scheme {
            var arguments = [String]()
            
            if let project = Args.shared.project {
                arguments += ["-project", project]
            } else if let workspace = Args.shared.workspace {
                arguments += ["-workspace", workspace]
            }
            arguments += ["-scheme", scheme, "-sdk", "iphonesimulator", "run-tests", "-listTestsOnly"]
            if let testTarget = Args.shared.target {
                arguments += ["-only", testTarget]
            }
            
            let task = NSTask()
            task.launchPath = Args.xctool
            task.arguments = arguments
            
            let standardError = NSPipe()
            task.standardError = standardError
            standardError.fileHandleForReading.readabilityHandler = { handle in
                if let log = String(data: handle.availableData, encoding: NSUTF8StringEncoding) {
                    self.printLog(log)
                }
            }
            
            let standardOutput = NSPipe()
            task.standardOutput = standardOutput
            
            task.launch()
            task.waitUntilExit()
            
            if task.terminationStatus == 0 {
                let data = standardOutput.fileHandleForReading.readDataToEndOfFile()
                if data.length > 0, let log = String(data: data, encoding: NSUTF8StringEncoding) {
                    for line in log.componentsSeparatedByString("\n") {
                        let trimmed = line.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceCharacterSet())
                        if trimmed.hasPrefix("~") {
                            var className: String?
                            var testName: String?
                            
                            for (i, part) in trimmed.componentsSeparatedByString(" ").enumerate() {
                                if i == 1 && part.hasPrefix("-[") {
                                    className = part.substringFromIndex(part.startIndex.advancedBy(2))
                                }
                                
                                if i == 2 && part.hasSuffix("]") {
                                    testName = part.substringToIndex(part.endIndex.advancedBy(-1))
                                }
                            }
                            
                            if let className = className, testName = testName {
                                tests.append(String(format: "%@/%@", className, testName))
                            }
                        }
                    }
                }
            }
        }
        
        return tests
    }
    
    func buildTests() -> Bool {
        if !build {
            return true
        }
        
        var success = false
        
        if let scheme = Args.shared.scheme {
            var arguments = [String]()
            
            if let project = Args.shared.project {
                arguments += ["-project", project]
            } else if let workspace = Args.shared.workspace {
                arguments += ["-workspace", workspace]
            }
            arguments += ["-scheme", scheme, "-sdk", "iphonesimulator", "build-tests", "-reporter", "plain"]
            
            let task = NSTask()
            task.launchPath = Args.xctool
            task.arguments = arguments
            
            let standardError = NSPipe()
            task.standardError = standardError
            standardError.fileHandleForReading.readabilityHandler = { handle in
                if let log = String(data: handle.availableData, encoding: NSUTF8StringEncoding) {
                    self.printLog(log)
                }
            }
            
            let standardOutput = NSPipe()
            task.standardOutput = standardOutput
            standardOutput.fileHandleForReading.readabilityHandler = { handle in
                if let log = String(data: handle.availableData, encoding: NSUTF8StringEncoding) {
                    self.printLog(log)
                }
            }
            
            task.terminationHandler = { task in
                if task.terminationStatus == 0 {
                    success = true
                }
            }
            
            task.launch()
            task.waitUntilExit()
        }
        
        return success
    }
    
    func cleanBuild() -> Bool {
        if !clean {
            return true
        }
        
        var success = false
        
        if let scheme = Args.shared.scheme {
            var arguments = [String]()
            
            if let project = Args.shared.project {
                arguments += ["-project", project]
            } else if let workspace = Args.shared.workspace {
                arguments += ["-workspace", workspace]
            }
            arguments += ["-scheme", scheme, "clean", "-reporter", "plain"]
            
            let task = NSTask()
            task.launchPath = Args.xctool
            task.arguments = arguments
            
            let standardError = NSPipe()
            task.standardError = standardError
            standardError.fileHandleForReading.readabilityHandler = { handle in
                if let log = String(data: handle.availableData, encoding: NSUTF8StringEncoding) {
                    self.printLog(log)
                }
            }
            
            let standardOutput = NSPipe()
            task.standardOutput = standardOutput
            standardOutput.fileHandleForReading.readabilityHandler = { handle in
                if let log = String(data: handle.availableData, encoding: NSUTF8StringEncoding) {
                    self.printLog(log)
                }
            }
            
            task.terminationHandler = { task in
                if task.terminationStatus == 0 {
                    success = true
                }
            }
            
            task.launch()
            task.waitUntilExit()
        }
        
        return success
    }
    
    func resetAndCreateDevices() -> [String: [String]] {
        var deviceUDIDs = [String: [String]]()
        
        let outputPipe = NSPipe()
        
        let task = NSTask()
        task.launchPath = "/usr/bin/xcrun"
        task.arguments = ["simctl", "list", "-j"]
        task.standardOutput = outputPipe
        task.launch()
        task.waitUntilExit()
        
        if Int(task.terminationStatus) == 0 {
            let handle = outputPipe.fileHandleForReading
            let data = handle.readDataToEndOfFile()
            
            var deviceTypes = [String: String]()
            var runtimes = [String: String]()
            
            do {
                if let json = try NSJSONSerialization.JSONObjectWithData(data, options: []) as? [String: AnyObject] {
                    for (key, values) in json {
                        switch key {
                        case "devicetypes":
                            for value in values as? [[String: String]] ?? [] {
                                if let name = value["name"], identifier = value["identifier"] {
                                    deviceTypes[name] = identifier
                                }
                            }
                        case "runtimes":
                            for value in values as? [[String: String]] ?? [] {
                                if let name = value["name"], identifier = value["identifier"] {
                                    runtimes[name] = identifier
                                }
                            }
                        default:
                            break
                        }
                    }
                }
            } catch {
                print(error)
            }
            
            if let devices = Args.shared.devices {
                for device in devices.componentsSeparatedByString(";") {
                    print("Creating", Args.shared.simulatorsCount ?? 1, device, "devices for testing")
                    
                    let parts = device.componentsSeparatedByString(",")
                    if parts.count == 2, let name = parts.first, runtime = parts.last {
                        if let deviceTypeID = deviceTypes[name], runtimeID = runtimes[runtime] {
                            
                            for i in 0..<(Args.shared.simulatorsCount ?? 1) {
                                let deviceName = String(format: "%@-%@-(%d)", name, runtime, i+1)
                                
                                let deleteDeviceTask = NSTask()
                                deleteDeviceTask.launchPath = "/usr/bin/xcrun"
                                deleteDeviceTask.arguments = ["simctl", "delete", deviceName]
                                deleteDeviceTask.launch()
                                deleteDeviceTask.waitUntilExit()
                                
                                let createDeviceOutput = NSPipe()
                                let createDeviceTask = NSTask()
                                createDeviceTask.launchPath = "/usr/bin/xcrun"
                                createDeviceTask.arguments = ["simctl", "create", deviceName, deviceTypeID, runtimeID]
                                createDeviceTask.standardOutput = createDeviceOutput
                                createDeviceTask.launch()
                                createDeviceTask.waitUntilExit()
                                
                                let handle = createDeviceOutput.fileHandleForReading
                                let data = handle.readDataToEndOfFile()
                                if var deviceID = String(data: data, encoding: NSUTF8StringEncoding) {
                                    deviceID = deviceID.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceAndNewlineCharacterSet())
                                    
                                    if var devices = deviceUDIDs[device] {
                                        devices.append(deviceID)
                                        deviceUDIDs[device] = devices
                                    } else {
                                        deviceUDIDs[device] = [deviceID]
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        
        return deviceUDIDs
    }
    
}