//
//  XSizeCounter.swift
//  XAtomation
//
//  Created by 谢鸿标 on 2020/3/26.
//  Copyright © 2020 谢鸿标. All rights reserved.
//

import Foundation

struct XArchSizeInfo {
    var arch: XPackageiOSArch
    var size: Double
}

struct XArchAvgSizeInfo {
    var size: Double
    var count: Int
    var avgSize: String {
        return String(round_d: size / Double(count), b: 2)
    }
}

struct XSymbolMapInfo {
    var fileName: String
    var fileSize: Int
}

struct XSymbolResult {
    var arch: XPackageiOSArch
    var symbols: [XSymbolMapInfo]
}

extension String {
    func toRange(range: NSRange) -> Range<String.Index>? {
        guard let from16 = utf16.index(utf16.startIndex, offsetBy: range.location, limitedBy: utf16.endIndex) else { return nil }
        guard let to16 = utf16.index(from16, offsetBy: range.length, limitedBy: utf16.endIndex) else { return nil }
        guard let from = String.Index(from16, within: self) else { return nil }
        guard let to = String.Index(to16, within: self) else { return nil }
        return from ..< to
    }
    var hexInt: Int {
        let hexScanner = Scanner(string: self)
        var hexInt: UInt64 = 0
        hexScanner.scanHexInt64(&hexInt)
        return Int(hexInt)
    }
}

public extension String {
    init(round_d: Double, b: Int) {
        let p = pow(10, Double(b))
        self.init(format: "%.\(b)f", round(round_d * p) / p)
    }
    init(round_f: Float, b: Int) {
        let p = powf(10, Float(b))
        self.init(format: "%.\(b)f", roundf(round_f * p) / p)
    }
}

// MARK: 使用Size命令计算Framework增量
class XFrameworkSizeCounter {
    
    public var archs = XPackageiOSArch.allArchs
    
    public func countFrameworkSize(filePath: String) throws -> [XArchSizeInfo] {
        if !filePath.hasSuffix(".framework") {
            throw XPackageError(code: 400, desc: "非.framework格式文件")
        }
        let output = "ls \(filePath)".syncNormalCmd;
        if output.count == 0 {
            throw XCommandError
        }
        var file = output.components(separatedBy: "\n").filter {
            let itemPath = "\(filePath)/\($0)"
            let res = "lipo -info \(itemPath)".syncNormalCmd
            return res.contains("Architectures in the fat")
        }.first ?? ""
        if file == "" {
            throw XPackageError(code: 400, desc: "当前路径找不到fat文件")
        }
        file = "\(filePath)/\(file)"
        // lipo -info %s | sed -En -e "s/^(Non-|Architectures in the )fat file: .+( is architecture| are): (.*)$/\\3/p"
        let countCmd = "lipo -info \(file) | sed -En -e \"s/^(Non-|Architectures in the )fat file: .+( is architecture| are): (.*)$/\\3/p\""
        let countRes = countCmd.syncNormalCmd
        XDebugPrint(debugDescription: "countCmd Result", object: "file: \(file)\nCMD: \(countCmd)")
        if countRes == "" {
            throw XCommandError
        }
        var archSizeInfo = [XArchSizeInfo]()
        _ = self.archs.map {
            let arch = $0.rawValue
            if countRes.contains(arch) {
                // lipo -thin %s %s -output %s_%s.a
                let thinCmd = "lipo -thin \(arch) \(file) -output \(file)_\(arch).a"
                _ = thinCmd.syncNormalCmd
                let sizeCmd = "size \(file)_\(arch).a | awk '{printf \"%s\\n\",$1}'"
                let sizeResult = sizeCmd.syncNormalCmd
                if sizeResult.count > 0 {
                    let sizeResults = sizeResult.components(separatedBy: "\n")
                    let sizeNum = sizeResults.filter {
                        return ($0 != "__DATA" || $0 != "__TEXT")
                    }.map {
                        return Double($0) ?? 0.0
                    }.reduce(0, +) / 1024.0
                    _ = "rm -fr \(file)_\(arch).a".syncNormalCmd
                    archSizeInfo.append(XArchSizeInfo(arch: $0, size: sizeNum))
                }
            }
        }
        return archSizeInfo
    }
}

// MARK: 分析Link-Map文件得出SDK增量
class XLinkMapSizeCounter {
    
    public func analyzeLinkMap(filePath: String) throws -> XSymbolResult {
        if filePath == "" {
            throw XPackageError(code: 400, desc: "文件不存在")
        }
        guard let content = try? String(contentsOfFile: filePath) else {
            throw XPackageError(code: 401, desc: "读取文件内容失败")
        }
        let validateContent = content.contains("# Object files:") &&
                              content.contains("# Sections:") &&
                              content.contains("# Symbols:") &&
                              content.contains("# Dead Stripped Symbols:") &&
                              content.contains("# Arch:")
        if !validateContent {
            throw XPackageError(code: 401, desc: "文件格式有误")
        }
        
        //获取Link-Map的架构信息
        let archString = self.fetchPoundContent(targetPound: "# Arch:", endPound: "# Object files:", linkMapContent: content).replacingOccurrences(of: " ", with: "")
        guard let arch = XPackageiOSArch.init(rawValue: archString) else {
            throw XPackageError(code: 402, desc: "Link-Map的架构信息未知")
        }
        let symbolMap = self.fetchSymbolMap(content: content)
        var symbolInfos = [XSymbolMapInfo]()
        _ = symbolMap.mapValues { (info) in
            if let fileName = info.fileName.components(separatedBy: "/").last {
                let symbolInfo = XSymbolMapInfo(fileName: fileName, fileSize: info.fileSize)
                symbolInfos.append(symbolInfo)
            }
        }
        symbolInfos.sort(by: { $0.fileName < $1.fileName})
        return XSymbolResult(arch: arch, symbols: symbolInfos)
    }
    
    private func fetchSymbolMap(content: String) -> Dictionary<String, XSymbolMapInfo> {
        var objectFilesMap = Dictionary<String, XSymbolMapInfo>()
        if let objFileRange = content.range(of: "# Object files:"),
           let sectionRange = content.range(of: "# Sections:"),
           let symbolRange = content.range(of: "# Symbols:"),
           let deadStrippedRange = content.range(of: "# Dead Stripped Symbols:") {
            
            //1.获取Object File编译内容
            let objFileContent = String(content[objFileRange.upperBound..<sectionRange.lowerBound])
            _ = objFileContent.components(separatedBy: "\n").map { (objFileLine) in
                
                if let indexInfo = self.matchObjectFileIndex(line: objFileLine) {
                    let fileName = String(objFileLine[indexInfo.range.upperBound..<objFileLine.endIndex])
                    objectFilesMap[indexInfo.index] = XSymbolMapInfo(fileName: fileName, fileSize: 0)
                }
            }
            //2.获取Symbol编译内容
            let symbolContent = String(content[symbolRange.upperBound..<deadStrippedRange.lowerBound])
            _ = symbolContent.components(separatedBy: "\n").map { (symbolLine) in
                let symbols = symbolLine.components(separatedBy: "\t")
                if symbols.count == 3,
                   let indexInfo = self.matchObjectFileIndex(line: symbols[2]),
                   var info = objectFilesMap[indexInfo.index] {
                    let size = symbols[1].hexInt
                    info.fileSize += size
                    objectFilesMap[indexInfo.index] = info
                }
            }
        }
        return objectFilesMap
    }
    
    typealias XObjectFileIndex = (index: String, range: Range<String.Index>)
    private func matchObjectFileIndex(line: String) -> XObjectFileIndex? {
        var indexInfo: XObjectFileIndex?
        do {
            let regx = try NSRegularExpression(pattern: "\\[ {1,}[0-9]+\\]", options: [])
            _ = regx.matches(in: line, options: [], range: NSMakeRange(0, line.count)).map { (result) in
                if let targetRange = line.toRange(range: result.range) {
                    indexInfo = (index: String(line[targetRange]), range: targetRange)
                }
            }
        } catch {
            XDebugPrint(debugDescription: "正则匹配Object Files索引出错", object: error)
        }
        return indexInfo
    }
    
    private func fetchPoundContent(targetPound: String, endPound: String, linkMapContent: String) -> String {
        var targetContent = ""
        if let targetRange = linkMapContent.range(of: targetPound),
           let endRange = linkMapContent.range(of: endPound) {
            targetContent = String(linkMapContent[targetRange.upperBound..<endRange.lowerBound])
        }
        return targetContent.replacingOccurrences(of: "\n", with: "")
    }
}

class XSizeCounter {
    
    private var linkMapCounter = XLinkMapSizeCounter()
    private var frameworkCounter = XFrameworkSizeCounter()
    private var linkMapResult: XSymbolResult?
    
    public var filePath = "" {
        didSet {
            if filePath.contains("&") {
                filePath = filePath.replacingOccurrences(of: "&", with: "\\&")
                self.linkMapResult = nil
            }
        }
    }
    public var moduleName = ""
    
    public func countSize() -> String {
        var sizeDescription = ""
        do {
            if self.filePath.hasSuffix(".framework") {
                let archSizeInfos = try self.frameworkCounter.countFrameworkSize(filePath: self.filePath)
                var simAvgSize = XArchAvgSizeInfo(size: 0.0, count: 0),
                    devAvgSize = XArchAvgSizeInfo(size: 0.0, count: 0)
                _ = archSizeInfos.map {
                    if $0.arch.isSimulator {
                        simAvgSize.size += $0.size
                        simAvgSize.count += 1
                    }else {
                        devAvgSize.size += $0.size
                        devAvgSize.count += 1
                    }
                    sizeDescription += "\($0.arch.rawValue) = \(String(format: "%.2f", $0.size))kb \n"
                }
                
                sizeDescription += "虚拟机平均增量：\(simAvgSize.avgSize)kb\n真机平均增量：\(devAvgSize.avgSize)kb"
            }else {
                var sizeCount = 0.0
                let result = try (self.linkMapResult ?? self.linkMapCounter.analyzeLinkMap(filePath: self.filePath))
                sizeDescription += "Link-Map记录的编译设备架构：\(result.arch.rawValue)\n"
                _ = result.symbols.filter { (symbol) in
                    let empty = (self.moduleName == "")
                    return !empty ? symbol.fileName.contains(self.moduleName) : true
                }.map { (symbol) in
                    let size = Double(symbol.fileSize)/1024.0
                    sizeDescription += "\(symbol.fileName) = \(String(format: "%.2f", size))kb\n"
                    sizeCount += size
                }
                sizeDescription += "总计：\(String(format: "%.2f",sizeCount))kb\n"
            }
            
        }catch {
            sizeDescription += "\(error)"
            XDebugPrint(debugDescription: "计算Framework增量出错", object: error)
        }
        return sizeDescription
    }
}
