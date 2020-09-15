//
//  XCommandLine.swift
//  XAtomation
//
//  Created by 谢鸿标 on 2020/1/22.
//  Copyright © 2020 谢鸿标. All rights reserved.
//

import Cocoa
import ServiceManagement

let XCommandError = XPackageError(code: 401, desc: "命令行输出异常")

public enum XResult<Success, Failure: Error> {
    case success(Success)
    case failure(Failure)
    
    public init(success: Success) {
        self = .success(success)
    }
    
    public init(failure: Failure) {
        self = .failure(failure)
    }
}

public typealias XCommandResult = (_ result: XResult<String,Error>) -> Void

public enum XCommandString {
    
    //Xcode的pbxproj文件转json文件
    case pbxTojson(String,String)
    //json文件转成Xcode的pbxproj文件
    case jsonTopbx(String,String)
    //删除文件
    case removeFile(String)
    //进入某个路径
    case cdPath(String)
    //列出当前文件夹的内容
    case listItems
    
    var commandString: String {
        switch self {
        case .pbxTojson(let jsonPath, let xmlPath):
            return "plutil -convert json -s -r -o \(jsonPath) \(xmlPath)"
        case .jsonTopbx(let xmlPath, let jsonPath):
            return "plutil -convert xml1 -s -r -o \(xmlPath) \(jsonPath)"
        case .removeFile(let file):
            return "rm -fr \(file)"
        case .cdPath(let path):
            return "cd \(path)"
        case .listItems:
            return "ls"
        }
    }
}

public extension String {
    
    /// 使用Proccess，Pipe同步执行命令
    var syncNormalCmd: String {
        let process = Process()
        //使用shell命令执行
        process.launchPath = "/bin/bash"
        //设置执行命令的格式
        process.arguments = ["-c", self]
        //新建管道输出Process
        let pipe = Pipe()
        process.standardOutput = pipe
        //开始Process
        process.launch()
        //获取运行结果
        let file = pipe.fileHandleForReading
        let data = file.readDataToEndOfFile()
        
        return String(data: data, encoding: .utf8) ?? ""
    }
    
    /// 使用Proccess，Pipe异步执行命令
    /// - Parameter completion: 回调
    func asyncNormalCmd(completion: @escaping XCommandResult) {
        DispatchQueue.global().async {
            let result = self.syncNormalCmd
            if result.count == 0 ||
                result.contains("Command not found") ||
                result.contains("No such file or directory") {
                completion(XResult(failure: XCommandError))
            }else {
                completion(XResult(success: result))
            }
        }
    }
    
    /// 超管权限异步执行命令
    /// - Parameter completion: 回调
    func authorizedCmd(completion: @escaping XCommandResult) {
        let appleScript = "do shell script \"\(self)\" with administrator privileges"
        let scriptFileName = "AppleScript.scpt"
        if let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            let scriptFilePath = dir.appendingPathComponent(scriptFileName)
            do {
                try appleScript.write(to: scriptFilePath, atomically: true, encoding: .utf8)
                let task = try NSUserAppleScriptTask(url: scriptFilePath)
                task.execute(withAppleEvent: nil) { (result, error) in
                    if result != nil {
                        completion(XResult(success: result!.stringValue ?? ""))
                        XDebugPrint(debugDescription: "执行结果", object: result)
                    }else {
                        completion(XResult(failure: error!))
                        XDebugPrint(debugDescription: "执行出错", object: error)
                    }
                }
            } catch  {
                completion(XResult(failure: error))
                XDebugPrint(debugDescription: "写入脚本失败", object: error)
            }
        }
    }
}
