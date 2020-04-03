//
//  XCommandLine.swift
//  XAtomation
//
//  Created by 谢鸿标 on 2020/1/22.
//  Copyright © 2020 谢鸿标. All rights reserved.
//

import Cocoa

let XCommandError = XPackageError(code: 401, desc: "命令行输出异常")

enum XCommandString {
    
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

func XCommandLineLaunch(cmd: XCommandString) -> Data {
    return XCommandLineLaunch(cmd: cmd.commandString)
}

/// 输入命令，然后执行，相当于在终端的操作（注：某些命令执行结束后无返回值，Data对象是空内容）
/// - Parameter cmd: 终端的可执行命令
func XCommandLineLaunch(cmd: String) -> Data {
    
    let process = Process()
    //使用shell命令执行
    process.launchPath = "/bin/bash"
    //设置执行命令的格式
    process.arguments = ["-c", cmd]
    //新建管道输出Process
    let pipe = Pipe()
    process.standardOutput = pipe
    //开始Process
    process.launch()
    //获取运行结果
    let file = pipe.fileHandleForReading
    let data = file.readDataToEndOfFile()
    
    return data
}
