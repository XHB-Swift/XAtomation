//
//  XFrameworkView.swift
//  XAtomation
//
//  Created by 谢鸿标 on 2020/3/26.
//  Copyright © 2020 谢鸿标. All rights reserved.
//

import Cocoa

public let kXFrameworkDebugSymbol = "debugSymbol"

protocol XFrameworkViewDelegate: class {
    
    func frameworkView(view: XFrameworkView, didStartPackage info: [String : Any])
}

class XFrameworkView: NSView, XLoadingDelegate {
    
    weak var frameworkDelegate: XFrameworkViewDelegate?
    
    @IBOutlet private weak var packageButton: NSButton?
    private var debugSymbol: Bool = false
    
    @IBAction func radioButtonAction(sender: NSButton) {
        self.debugSymbol = (sender.title == "True")
    }
    
    @IBAction func startPackageButtonAction(sender: NSButton) {
        self.frameworkDelegate?.frameworkView(view: self, didStartPackage: [kXFrameworkDebugSymbol:self.debugSymbol])
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
