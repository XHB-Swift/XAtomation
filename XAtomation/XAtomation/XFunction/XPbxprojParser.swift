//
//  XPbxprojParser.swift
//  XAtomation
//
//  Created by 谢鸿标 on 2020/2/2.
//  Copyright © 2020 谢鸿标. All rights reserved.
//

import Foundation

//target结构
public struct XPbxprojTarget {
    var targetName: String
    var targetId: String
    var productType: String
    var infoPlist: String
}

public enum XBoolInfo: String {
    case `true` = "YES"
    case `false` = "NO"
    
    public var boolValue: Bool {
        switch self {
        case .`true`:
            return true
        default:
            return false
        }
    }
}

extension String {
    
    enum XProjectFileType: String {
        case pbxproj = ".pbxproj"
        case xcworkspace = ".xcworkspace"
    }
    
    /// 根据Xcode工程路径获取.xcodeproj的project文件路径
    /// - Parameter fileType: 文件类型
    func fetchProjectPathInfo(fileType: XProjectFileType) -> (hasPath: Bool, path: String) {
        let filePath = self.replacingOccurrences(of: "(", with: "\\(").replacingOccurrences(of: ")", with: "\\)")
        let cmdContent = "cd \(filePath);ls".syncNormalCmd
        var result = (false,"")
        if cmdContent.count == 0 {
            return result
        }
        let paths = cmdContent.components(separatedBy: "\n")
        let xcodeprojPaths = paths.filter { (path) in
            return (path.contains(".xcodeproj"))
        }
        guard let xcodeprojPath = xcodeprojPaths.first else {
            return result
        }
        let pbxprojPath = "\(filePath)/\(xcodeprojPath)/project\(fileType.rawValue)"
        let fm = FileManager.default
        result.0 = fm.fileExists(atPath: pbxprojPath)
        if result.0 {
            result.1 = pbxprojPath
        }
        return result
    }
}

class XPbxprojParser {
    
    private var pbxprojXMLFilePath = ""
    private var pbxprojJSONFilePath = ""
    private var pbxprojJSON: [String:Any]?
    private var targets = [XPbxprojTarget]()
    
    //Xcode工程路径
    public var xcodeProjectPath = ""
    
    //获取所有Target的名称
    public var allTargetNames: [String] {
        return self.targets.map { (target) in
            return target.targetName
        }
    }
    
    //加载转换后的pb json文件
    func loadPbxprojContent() {
        
        let pbxprojPathInfo = self.xcodeProjectPath.fetchProjectPathInfo(fileType: String.XProjectFileType.pbxproj)
        if pbxprojPathInfo.hasPath {
            self.pbxprojXMLFilePath = pbxprojPathInfo.path;
            self.pbxprojJSONFilePath = "\(self.pbxprojXMLFilePath).json"
            //pbxproj转json在cmd没有结果返回，即""字符串
            _ = XCommandString.pbxTojson(self.pbxprojJSONFilePath, self.pbxprojXMLFilePath).commandString.syncNormalCmd
            do {
                let pbxprojJSONFileURL = URL(fileURLWithPath: self.pbxprojJSONFilePath)
                let pbxprojFileJSONData = try Data(contentsOf: pbxprojJSONFileURL)
                self.pbxprojJSON = try JSONSerialization.jsonObject(with: pbxprojFileJSONData, options: JSONSerialization.ReadingOptions.allowFragments) as? [String : Any]
            } catch  {
                XDebugPrint(debugDescription: "load json failed", object: error)
            }
        }else {
            XDebugPrint(debugDescription: "pbxprojFilePath路径为空", object: nil)
        }
    }
    
    //保存设置
    func storePbxprojContent() {
        if let json = self.pbxprojJSON {
            do {
                let data = try JSONSerialization.data(withJSONObject: json, options: JSONSerialization.WritingOptions.prettyPrinted)
                let pbxprojXMLFileURL = URL(fileURLWithPath: self.pbxprojXMLFilePath)
                try data.write(to: pbxprojXMLFileURL)
                //修改完毕即可保存配置
                let jsonToXmlCmd = XCommandString.jsonTopbx(self.pbxprojXMLFilePath, self.pbxprojJSONFilePath)
                //json转成xml
                _ = jsonToXmlCmd.commandString.syncNormalCmd
                let removeFileCmd = XCommandString.removeFile(self.pbxprojJSONFilePath)
                //删除json文件
                _ = removeFileCmd.commandString.syncNormalCmd
            }catch {
                XDebugPrint(debugDescription: "store pbxproj file failed", object: error)
            }
        }else {
            XDebugPrint(debugDescription: "pbxprojJSON为空", object: nil)
        }
    }
    
    //获取Target信息
    func serializeTargets() {
        if let json = self.pbxprojJSON,
            let objects = json["objects"] as? [String:Any],
            let rootObject = json["rootObject"] as? String,
            let podInfo = objects[rootObject] as? [String:Any],
            let targetInfos = podInfo["targets"] as? [String] {
            
            _ = targetInfos.map { target in
                if let info = objects[target] as? [String:Any],
                    let productType = info["productType"] as? String,
                    let targetName = info["name"] as? String,
                    let buildConfigurationListID = info["buildConfigurationList"] as? String,
                    let buildConfigurationInfo = objects[buildConfigurationListID] as? [String:Any],
                    let buildConfigurations = buildConfigurationInfo["buildConfigurations"] as? [String],
                    let debugBuildConfigurationID = buildConfigurations.first,
                    let debugBuildConfiguration = objects[debugBuildConfigurationID] as? [String:Any],
                    let buildSettings = debugBuildConfiguration["buildSettings"] as? [String:Any],
                    let infoFilePath = buildSettings["INFOPLIST_FILE"] as? String {
                    self.targets.append(XPbxprojTarget(targetName: targetName,
                                                       targetId: target,
                                                       productType: productType,
                                                       infoPlist: infoFilePath.replacingOccurrences(of: "$(SRCROOT)", with: "")))
                }
            }
        }
    }
    
    //根据索引获取Target
    func target(at index: Int) -> XPbxprojTarget? {
        let targetCount = self.targets.count
        return (targetCount > index) ? self.targets[index] : nil
    }
    
    //获取包含BuildSettings的字段
    private func buildSettingsKeys() -> [String] {
        var buildSettings = [String]()
        if let json = self.pbxprojJSON?["objects"] as? [String:Any] {
            _ = json.map { (key,value) in
                if key == "buildSettings" {
                    buildSettings.append(key)
                }
            }
        }
        return buildSettings
    }
}

extension XPbxprojParser {
    //Xcode配置文件的BuildSetting常用字段
    enum XBuildSettingKeys: String {
        //打包类型
        case MACH_O_TYPE = "MACH_O_TYPE"
        //是否开启BitCode
        case ENABLE_BITCODE = "ENABLE_BITCODE"
        //证书设置
        case CODE_SIGN_STYLE = "CODE_SIGN_STYLE"
        //Link-Map路径
        case LD_MAP_FILE_PATH = "LD_MAP_FILE_PATH"
        //研发团队
        case DEVELOPMENT_TEAM = "DEVELOPMENT_TEAM"
        //验证身份
        case CODE_SIGN_IDENTITY = "CODE_SIGN_IDENTITY"
        //是否生成Link-Map
        case LD_GENERATE_MAP_FILE = "LD_GENERATE_MAP_FILE"
        //BundleId
        case PRODUCT_BUNDLE_IDENTIFIER = "PRODUCT_BUNDLE_IDENTIFIER"
        //验证身份
        case CODE_SIGN_IDENTITY_IPHONE = "CODE_SIGN_IDENTITY[sdk=iphoneos*]"
        //部署到iOS版本
        case IPHONEOS_DEPLOYMENT_TARGET = "IPHONEOS_DEPLOYMENT_TARGET"
        //是否生成Debug断点
        case GCC_GENERATE_DEBUGGING_SYMBOLS = "GCC_GENERATE_DEBUGGING_SYMBOLS"
        //描述文件设置
        case PROVISIONING_PROFILE_SPECIFIER = "PROVISIONING_PROFILE_SPECIFIER"
    }
    
    typealias XBuildSettingsData = [XBuildSettingKeys:String]
    
    //集中修改BuildSettings设置
    func setBuildSettingsData(buildSettingsData: XBuildSettingsData) {
        if let json = self.pbxprojJSON {
            let targetKeys = self.buildSettingsKeys()
            _ = targetKeys.map { targetKey in
                if let objects = json["objects"] as? [String:Any],
                   let targetObject = objects[targetKey] as? [String:Any],
                   var buildSettings = targetObject["buildSettings"] as? [String:Any] {
                    _ = buildSettingsData.map { (key,value) in
                        buildSettings[key.rawValue] = value
                    }
                }else {
                    XDebugPrint(debugDescription: "json-objects: 拆包失败", object: json["objects"])
                }
            }
            //覆盖保存配置
            self.pbxprojJSON = json
            self.storePbxprojContent()
        }else {
            XDebugPrint(debugDescription: "self.pbxprojJSON", object: "nil json")
        }
    }
}

extension XPbxprojParser: XDebugProtocol {
    var description: String {
        return "xml file = \(self.pbxprojXMLFilePath),\njson file = \(self.pbxprojJSONFilePath),\njson = \(String(describing: self.pbxprojJSON)),\ntargets = \(self.targets)"
    }
}
