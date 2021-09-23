//
//  XFrameworkView.swift
//  XAtomation
//
//  Created by 谢鸿标 on 2020/3/26.
//  Copyright © 2020 谢鸿标. All rights reserved.
//

import Cocoa

public let kXFrameworkDebugSymbol = "debugSymbol"

protocol XFrameworkViewDelegate: AnyObject {
    
    func frameworkView(view: XFrameworkView, didStartPackage info: [String : Any])
    func frameworkView(view: XFrameworkView, didFetchXcodeVersionFromPath path: String)
}

class XFrameworkView: NSView, XLoadingDelegate {
    
    weak var frameworkDelegate: XFrameworkViewDelegate?
    
    @IBOutlet private weak var packageButton: NSButton?
    @IBOutlet private weak var xcodeVersionLbl: NSTextField?
    private var debugSymbol: Bool = false
    
    public func setXcodeVersion(version: String) {
        self.xcodeVersionLbl?.stringValue = version
    }
    
    @IBAction func radioButtonAction(sender: NSButton) {
        self.debugSymbol = (sender.title == "True")
    }
    
    @IBAction func startPackageButtonAction(sender: NSButton) {
        self.frameworkDelegate?.frameworkView(view: self, didStartPackage: [kXFrameworkDebugSymbol:self.debugSymbol])
    }
    
    @IBAction func switchXcodeVersion(sender: NSButton) {
        guard let window = self.window else {
            return
        }
        let panel = NSOpenPanel()
        panel.canCreateDirectories = false
        panel.canChooseDirectories = true
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        panel.beginSheetModal(for: window) { response in
            if response != .OK {
                return
            }
            guard let path = panel.urls.first?.path else {
                return
            }
            let xcDevPath = path + "/Contents/Developer"
            self.frameworkDelegate?.frameworkView(view: self, didFetchXcodeVersionFromPath: xcDevPath)
        }
    }
    
    func startLoading() {
        self.packageButton?.title = "正在打包..."
        self.packageButton?.isEnabled = false
    }
    
    func stopLoading() {
        self.packageButton?.title = "开始打包SDK"
        self.packageButton?.isEnabled = true
    }
}
