//
//  XAtomationViewController.swift
//  XAtomation
//
//  Created by 谢鸿标 on 2020/1/22.
//  Copyright © 2020 谢鸿标. All rights reserved.
//

import Cocoa

func showAlert(message: String, for window: NSWindow?) {
    if let vWindow = window {
        let alert = NSAlert()
        alert.addButton(withTitle: "确定")
        alert.messageText = message
        alert.alertStyle = .warning
        alert.beginSheetModal(for: vWindow, completionHandler: nil)
    }else {
        XDebugPrint(debugDescription: "Window对象为nil", object: nil)
    }
}

class XAtomationViewController: NSViewController {
    
    @IBOutlet private weak var dragView: XDragView?
    @IBOutlet private weak var frameworkView: XFrameworkView?
    @IBOutlet private weak var sizeCounterView: XSizeCounterView?
    
    private let pbxprojParser = XPbxprojParser()
    private let frameworkPackage = XFrameworkPackage()
    private let sizeCounter = XSizeCounter()

    override func viewDidLoad() {
        super.viewDidLoad()
        self.dragView?.dragDelegate = self
        self.frameworkView?.frameworkDelegate = self
        self.sizeCounterView?.dragDelegate = self
    }
    
    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }
}

extension XAtomationViewController: XDragDelegate {
    
    func dragView(view: NSView, didDragFilePath filePath: String) {
        if view is XDragView {
            self.pbxprojParser.xcodeProjectPath = filePath
            self.pbxprojParser.loadPbxprojContent()
            self.pbxprojParser.serializeTargets()
        }else if view is XSizeCounterView {
            self.sizeCounterView?.startLoading()
            DispatchQueue.global().async {
                self.sizeCounter.filePath = filePath
                let frameworkSize = self.sizeCounter.countSize()
                DispatchQueue.main.async {
                    self.sizeCounterView?.stopLoading()
                    self.sizeCounterView?.updateContentText(text: frameworkSize)
                }
            }
        }
    }
    
    func dragView(view: NSView, didSelectTargetAtIndex index: Int) {
        if view is XDragView {
            if let target = self.pbxprojParser.target(at: index-1) {
                let xcodeprojPath = self.pbxprojParser.xcodeProjectPath.fetchProjectPathInfo(fileType: String.XProjectFileType.xcworkspace)
                let archs = XPackageiOSArch.allArchs
                if xcodeprojPath.hasPath {
                    //配置打包SDK参数
                    self.pbxprojParser.setBuildSettingsData(buildSettingsData: [.MACH_O_TYPE:"staticlib"])
                    self.frameworkPackage.packageInfo = XFrameworkPackageInfo(xcodeProjPath: xcodeprojPath.path, target: target, archs: archs)
                }else {
                    showAlert(message: "未检测到Xcode工程路径", for: self.view.window)
                }
            }else {
                showAlert(message: "未检测到Xcode工程Target", for: self.view.window)
            }
        }else if view is XSizeCounterView {
            
        }
    }
}

extension XAtomationViewController: XDragViewDelegate {
    func popItems(in view: XDragView) -> [String] {
        var titles = ["请选择"]
        titles += self.pbxprojParser.allTargetNames
        return titles
    }
}

extension XAtomationViewController: XFrameworkViewDelegate {
    
    func frameworkView(view: XFrameworkView, didStartPackage info: [String : Any]) {
        guard let debugSymbol = info[kXFrameworkDebugSymbol] as? Bool else {
            return
        }
        let bitCodSettings = [XBoolInfo.true,XBoolInfo.false]
        let debugSymbolSetting = debugSymbol ? "YES" : "NO"
        self.pbxprojParser.setBuildSettingsData(buildSettingsData: [.GCC_GENERATE_DEBUGGING_SYMBOLS:debugSymbolSetting])
        view.startLoading()
        XAsyncExecute({
            _ = bitCodSettings.map { (bitCodSetting) in
                self.pbxprojParser.setBuildSettingsData(buildSettingsData: [.ENABLE_BITCODE:bitCodSetting.rawValue])
                self.frameworkPackage.bitCode = bitCodSetting.boolValue
                self.frameworkPackage.createFramework()
            }
            self.frameworkPackage.createAFramework()
        }) {
            view.stopLoading()
        }
    }
}

extension XAtomationViewController: XSizeCounterViewDelegate {
    
    func sizeCounter(view: XSizeCounterView, didFilterModule name: String) {
        self.sizeCounterView?.startLoading()
        DispatchQueue.global().async {
            self.sizeCounter.moduleName = name
            let frameworkSize = self.sizeCounter.countSize()
            DispatchQueue.main.async {
                self.sizeCounterView?.stopLoading()
                self.sizeCounterView?.updateContentText(text: frameworkSize)
            }
        }
    }
}
