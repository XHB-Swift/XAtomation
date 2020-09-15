//
//  XPackage.swift
//  XAtomation
//
//  Created by 谢鸿标 on 2020/2/2.
//  Copyright © 2020 谢鸿标. All rights reserved.
//

import Foundation

struct XPackageError: Error {
    var code: Int
    var desc: String
}

// MARK: 架构分类
public enum XPackageiOSArch: String {
    case i386   = "i386"
    case x86_64 = "x86_64"
    case armv7  = "armv7"
    case armv7s = "armv7s"
    case arm64  = "arm64"
    case arm64e = "arm64e" 
    
    var isSimulator: Bool {
        switch self {
        case .i386, .x86_64:
            return true
        default:
            return false
        }
    }
    static var allArchs: [XPackageiOSArch] {
        return [.i386,.x86_64,.armv7,.armv7s,.arm64,.arm64e]
    }
}

// MARK: 打包信息
public struct XFrameworkPackageInfo {
    var xcodeProjPath: String
    var target: XPbxprojTarget
    var archs: [XPackageiOSArch]
}

class XFrameworkPackage {
    
    // MARK: iOS打包真机模拟器指令分类
    private enum XPacakageBuildiOSPlatform: String {
        case iphoneos = "iphoneos"
        case iphonesimulator = "iphonesimulator"
    }
    
    // MARK: iOS平台信息结构
    private struct XPacakageiOSPlatformInfo {
        var arch: String //平台架构集合
        var platform: XPacakageBuildiOSPlatform //真机模拟器区分
    }
    
    // MARK: 记录打包成.framework之后的路径和文件名
    private struct XPackagePathInfo {
        var dirPath: String
        var fileName: String
    }
    private let buildScceededString = "** BUILD SUCCEEDED **"
    private var bitCodeDescription: String {
        return self.bitCode ? "bitcode" : ""
    }
    private var packagePathInfo: XPackagePathInfo?
    
    public var bitCode: Bool = true
    public var packageInfo: XFrameworkPackageInfo?
    
    // MARK: 切换Xcode版本
    static public func switchXcodeVersion(path: String, completion: @escaping (String)->Void) {
        //切换到目标Xcode路径
        XDebugPrint(debugDescription: "目标路径", object: path)
        "sudo xcode-select -s \(path)".authorizedCmd { result in
            switch result {
            case .success(_):
                self.fetchXcodeVersion(completion: completion)
            case .failure(let error):
                XDebugPrint(debugDescription: "切换目标路径异常", object: error)
            }
        }
    }
    
    // MARK: 异步获取Xcode版本
    static public func fetchXcodeVersion(completion: @escaping (String)->Void) {
        "xcode-select -p".asyncNormalCmd { result in
            switch result {
            case .success(let xcodeDeveloperPath):
                //获取info.plist
                let xcodeInfoPath = xcodeDeveloperPath.replacingOccurrences(of: "/Developer", with: "").replacingOccurrences(of: "\n", with: "") + "/Info.plist"
                if let info = NSDictionary(contentsOfFile: xcodeInfoPath),
                    let version = info["CFBundleShortVersionString"] as? String {
                    DispatchQueue.main.async {
                        completion(version)
                    }
                }
            case .failure(let error):
                XDebugPrint(debugDescription: "命令执行出错", object: error)
            }
        }
    }
    
    public func createFramework() {
        guard let info = self.packageInfo else {
            return
        }
        self.createFramework(xcodeProjPath: info.xcodeProjPath, target: info.target, iOSArchs: info.archs)
    }
    
    public func createFramework(xcodeProjPath: String, target: XPbxprojTarget, iOSArchs archs: [XPackageiOSArch]) {
        do {
            try self.buildFrameworkProject(xcodeProjPath: xcodeProjPath,
                                           target: target,
                                           iOSArchs: archs)
        } catch {
            XDebugPrint(debugDescription: "Build error", object: error)
        }
        self.deleteFrameworkDir(target: target)
    }
    
    // MARK: 生成.a格式的SDK
    public func createAFramework() {
        guard let pathInfo = self.packagePathInfo else {
            XDebugPrint(debugDescription: "先打包Framework格式文件才能生成.a文件", object: nil)
            return
        }
        let frameworkDir = pathInfo.dirPath
        let frameworkName = pathInfo.fileName
        let frameworkFile = "\(frameworkName).framework"
        //1.将前面生成的所有.framework全部复制到a文件夹下面
        let cpFrameworkCmd = "cp -fr \(frameworkDir)/framework \(frameworkDir)/a"
        _ = cpFrameworkCmd.syncNormalCmd
        //2.生成头文件文件夹
        let cpHeaderFileCmd = "cp -fr \(frameworkDir)/a/framework/模拟器/\(frameworkFile)/Headers     \(frameworkDir)/a/"
        _ = cpHeaderFileCmd.syncNormalCmd
        //3.获取framework的所有文件夹
        let allDirsCmd = "ls \(frameworkDir)/framework"
        let output = allDirsCmd.syncNormalCmd
        let dirs = output.components(separatedBy: "\n")
//        XDebugPrint(debugDescription: "输出文件夹", object: dirs)
        _ = dirs.filter { (dir) in
            return (dir.count > 0) //过滤掉""
        }.map {(dir) in
            let hasFmtSymboy = (dir.contains("&"))
            let fmtDir = hasFmtSymboy ? dir.replacingOccurrences(of: "&", with: "\\&") : dir
            let srcDir = "\(frameworkDir)/a/framework/\(fmtDir)/\(frameworkFile)/\(frameworkName)"
            let desDir = "\(frameworkDir)/a/\(fmtDir)/\(frameworkName).a"
            let cpDirCmd = "cp -fr \(srcDir) \(desDir)"
            _ = cpDirCmd.syncNormalCmd
            let rmFrwCmd = "rm -fr \(frameworkDir)/a/\(fmtDir)/\(frameworkFile)"
            _ = rmFrwCmd.syncNormalCmd
        }
        //4.删除framework文件夹
        let rmFrwDir = "rm -fr \(frameworkDir)/a/framework"
        _ = rmFrwDir.syncNormalCmd
    }
    
    // MARK: 创建Framework的SDK
    private func buildFrameworkProject(xcodeProjPath: String, target: XPbxprojTarget, iOSArchs archs: [XPackageiOSArch]) throws {
        
        if !target.productType.hasSuffix(".framework") {
            throw XPackageError(code: 400, desc: "不是framework工程")
        }
        if !xcodeProjPath.hasSuffix(".xcworkspace") {
            throw XPackageError(code: 400, desc: "找不到.xcworkspace文件")
        }
        let pathItems = xcodeProjPath.components(separatedBy: "/")
        let filterXcProjItems = pathItems.filter {
            return $0.contains(".xcodeproj")
        }
        guard let _ = filterXcProjItems.first else {
            throw XPackageError(code: 400, desc: "找不到.xcodeproj文件")
        }
        guard let _ = target.infoPlist.components(separatedBy: "/").last else {
            throw XPackageError(code: 400, desc: "找不到info.plist文件")
        }
        let projPath = pathItems[0...pathItems.count - 3].joined(separator: "/")
        let infoFolder = projPath + "/\(target.infoPlist)"
        self.backup(pbxproj: projPath, infoFolder: infoFolder)
        
        //构建打包framework目录
        let frameworkDir = self.createFrameworkDir(target: target)
        //所有要打包平台信息
        let platformInfos = self.createArchInfo(archs: archs)
        for platformInfo in platformInfos {
            let platform = platformInfo.platform
            let type = (platform == .iphoneos)
            let buildSuccess = self.xcodeBuildProject(xcodeProjPath: xcodeProjPath,
                                                      arch: platformInfo.arch,
                                                      outputDir:frameworkDir,
                                                      target: target,
                                                      platform: platform)
            if !buildSuccess { //先Build出Framework
                self.restore(pbxproj: projPath, infoFolder: infoFolder)
                throw XPackageError(code: 401, desc: "clean错误")
            }else { //再复制Framework
                self.copyFramework(targetName: target.targetName, type: type, frameworkDir: frameworkDir)
            }
        }
        //合并Framework
        self.mergeFramework(targetName: target.targetName, frameworkDir: frameworkDir)
        self.packagePathInfo = XPackagePathInfo(dirPath: frameworkDir, fileName: target.targetName)
    }
    
    // MARK: 生成打包真机模拟所需的架构
    private func createArchInfo(archs: [XPackageiOSArch]) -> [XPacakageiOSPlatformInfo] {
        //区分真机模拟器架构
        let simArch = archs.filter { (arch) in
            return (arch.isSimulator)
        }.map { (arch) in
            "-arch \(arch.rawValue) "
        }.joined()
        let devArch = archs.filter { (arch) in
            return !(arch.isSimulator)
        }.map { (arch) in
            "-arch \(arch.rawValue) "
        }.joined()
        //平台信息
        let platformInfos = [
            XPacakageiOSPlatformInfo(arch: devArch, platform: .iphoneos),
            XPacakageiOSPlatformInfo(arch: simArch, platform: .iphonesimulator)]
        return platformInfos
    }
    
    // MARK: Xcode Build项目
    private func xcodeBuildProject(xcodeProjPath: String,
                                   arch: String,
                                   outputDir: String,
                                   target: XPbxprojTarget,
                                   platform: XPacakageBuildiOSPlatform) -> Bool {
        var buildSuccess = false
        let buildCmd = "xcodebuild clean \(arch) -sdk \(platform.rawValue) -workspace \(xcodeProjPath) -scheme \(target.targetName) ONLY_ACTIVE_ARCH=NO -configuration Release clean build -derivedDataPath \(outputDir)/autoBuild"
        let cmdOutput = buildCmd.syncNormalCmd
        if cmdOutput.count == 0 {
            return buildSuccess
        }
        buildSuccess = cmdOutput.contains(self.buildScceededString)
        return buildSuccess
    }
    
    // MARK: 将Build好的Framework复制到指定目录
    private func copyFramework(targetName: String, type: Bool, frameworkDir: String) {
        let targetFramework = "\(targetName).framework"
        let description = type ? "真机" : "模拟器"
        let releaseType = type ? "iphoneos" : "iphonesimulator"
        let bitCodeDesc = self.bitCodeDescription
        let frameworkType = "\(self.bitCode ? "\(description)\(bitCodeDesc)" : description)"
        let srcFrameworkPath = "\(frameworkDir)/autoBuild/Build/Products/Release-\(releaseType)/\(targetFramework)"
        let destFrameworkPath = "\(frameworkDir)/framework/\(frameworkType)/"
        let copyFrameworkCmd = "cp -fr \(srcFrameworkPath) \(destFrameworkPath)"
        _ = copyFrameworkCmd.syncNormalCmd
    }
    
    // MARK: 合并真机&模拟器Framework到指定目录
    private func mergeFramework(targetName: String, frameworkDir: String) {
        let targetFramework = "\(targetName).framework"
        let bitCodeDesc = self.bitCodeDescription
        let copyFrameworkCmd = "cp -fr \(frameworkDir)/framework/真机\(bitCodeDesc)/\(targetFramework) \(frameworkDir)/framework/真机\\&模拟器\(bitCodeDesc)/\(targetFramework)"
        _ = copyFrameworkCmd.syncNormalCmd
        let rmFrameworkCmd = "rm -fr \(frameworkDir)/framework/真机\\&模拟器\(bitCodeDesc)/\(targetFramework)/\(targetName)"
        _ = rmFrameworkCmd.syncNormalCmd
        // lipo -create %s/framework/真机bitcode/%s.framework/%s %s/framework/模拟器bitcode/%s.framework/%s -output %s/framework/真机\&模拟器bitcode/%s.framework/%s
        let deviceFramework = "\(frameworkDir)/framework/真机\(bitCodeDesc)/\(targetFramework)/\(targetName)"
        let simulatorFramework = "\(frameworkDir)/framework/模拟器\(bitCodeDesc)/\(targetFramework)/\(targetName)"
        let outputDir = "\(frameworkDir)/framework/真机\\&模拟器\(bitCodeDesc)/\(targetFramework)/\(targetName)"
        let lipoCmd = "lipo -create \(deviceFramework) \(simulatorFramework) -output \(outputDir)"
        let outputCmd = lipoCmd.syncNormalCmd
        if outputCmd.count == 0 {
            XDebugPrint(debugDescription: "无法获取lipo指令执行结果", object: nil)
            return
        }
        if outputCmd.contains("error") {
            XDebugPrint(debugDescription: "合并异常", object: outputCmd)
            return
        }
    }
    
    // MARK: 生成打包Framework文件夹
    private func createFrameworkDir(target: XPbxprojTarget) -> String {
        var saveDir = ""
        let fm = FileManager.default
        if let url = fm.urls(for: .desktopDirectory, in: .userDomainMask).first {
            let dir_url = url.absoluteString + "auto_sdk_\(target.targetName)"
            saveDir = dir_url
            if saveDir.hasPrefix("file://") {
                saveDir = saveDir.replacingOccurrences(of: "file://", with: "")
            }
            let bitCodeDesc = self.bitCodeDescription
            _ = "mkdir -p \(saveDir)".syncNormalCmd
            _ = "mkdir -p \(saveDir)/framework".syncNormalCmd
            _ = "mkdir -p \(saveDir)/framework/模拟器\(bitCodeDesc)".syncNormalCmd
            _ = "mkdir -p \(saveDir)/framework/真机\(bitCodeDesc)".syncNormalCmd
            _ = "mkdir -p \(saveDir)/framework/真机\\&模拟器\(bitCodeDesc)".syncNormalCmd
        }
        return saveDir
    }
    
    // MARK: 删除打包过程生成的文件夹
    private func deleteFrameworkDir(target: XPbxprojTarget) {
        var saveDir = ""
        let fm = FileManager.default
        if let url = fm.urls(for: .desktopDirectory, in: .userDomainMask).first {
            let dir_url = url.absoluteString + "auto_sdk_\(target.targetName)"
            saveDir = dir_url
            if saveDir.hasPrefix("file://") {
                saveDir = saveDir.replacingOccurrences(of: "file://", with: "")
            }
            do {
                try fm.removeItem(atPath: saveDir)
            } catch  {
                XDebugPrint(debugDescription: "删除auto_sdk文件夹", object: error)
            }
        }
    }
    
    // MARK: 备份Xcode文件
    private func backup(pbxproj: String, infoFolder: String) {
        let pbx_rm_fr_cmd = "rm -fr \(pbxproj)_copy"
        let pbx_cp_fr_cmd = "cp -fr \(pbxproj) \(pbxproj)_copy"
        let info_rm_fr_cmd = "rm -fr \(infoFolder)_copy"
        let info_cp_fr_cmd = "cp -fr \(infoFolder) \(infoFolder)_copy"
        
        _ = pbx_rm_fr_cmd.syncNormalCmd
        _ = pbx_cp_fr_cmd.syncNormalCmd
        _ = info_rm_fr_cmd.syncNormalCmd
        _ = info_cp_fr_cmd.syncNormalCmd
    }
    
    // MARK: 回滚Xcode的文件
    private func restore(pbxproj: String, infoFolder: String) {
        let pbx_cp_fr_cmd = "cp -fr \(pbxproj)_copy \(pbxproj)"
        let pbx_rm_fr_cmd = "rm -fr \(pbxproj)_copy"
        let info_cp_fr_cmd = "cp -fr \(infoFolder)_copy \(infoFolder)"
        let info_rm_fr_cmd = "rm -fr \(infoFolder)_copy"
        
        _ = pbx_cp_fr_cmd.syncNormalCmd
        _ = pbx_rm_fr_cmd.syncNormalCmd
        _ = info_cp_fr_cmd.syncNormalCmd
        _ = info_rm_fr_cmd.syncNormalCmd
    }
    
}
