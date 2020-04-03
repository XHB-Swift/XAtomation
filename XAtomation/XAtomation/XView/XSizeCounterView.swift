//
//  XSizeCounterView.swift
//  XAtomation
//
//  Created by 谢鸿标 on 2020/3/26.
//  Copyright © 2020 谢鸿标. All rights reserved.
//

import Cocoa

protocol XSizeCounterViewDelegate: XDragDelegate {
    func sizeCounter(view: XSizeCounterView, didFilterModule name: String)
}

class XSizeCounterView: NSView, XLoadingDelegate {
    
    weak var dragDelegate: XSizeCounterViewDelegate?
    
    @IBOutlet private weak var exploreButton: NSButton?
    @IBOutlet private weak var resultView: NSTextView?
    @IBOutlet private weak var groupButton: NSButton?
    @IBOutlet private weak var groupTextField: NSTextField?

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        self.registerForDraggedTypes([NSPasteboard.PasteboardType.fileURL])
    }
    
    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        self.needsDisplay = true
        return NSDragOperation.copy
    }
    
    override func draggingExited(_ sender: NSDraggingInfo?) {
        self.needsDisplay = true
    }
    
    override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool {
        self.needsDisplay = true
        return true
    }
    
    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        if let draggingSource = sender.draggingSource as? XSizeCounterView, draggingSource != self {
            if let filePaths = sender.draggingPasteboard.propertyList(forType: NSPasteboard.PasteboardType.fileURL) as? [String],
                let filePath = filePaths.first {
                self.dragDelegate?.dragView(view: self, didDragFilePath: filePath)
            }
        }
        return true
    }
    
    @IBAction func countSizeAction(sender: NSButton) {
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
            self.dragDelegate?.dragView(view: self, didDragFilePath: path)
            XDebugPrint(debugDescription: "导入framework文件", object: path)
        }
    }
    
    @IBAction func groupButtonAction(sender: NSButton) {
        guard let moduleName = self.groupTextField?.stringValue else {
            return
        }
        self.dragDelegate?.sizeCounter(view: self, didFilterModule: moduleName)
    }
    
    func startLoading() {
        self.exploreButton?.title = "正在计算..."
        self.exploreButton?.isEnabled = false
    }
    
    func stopLoading() {
        self.exploreButton?.title = "浏览文件"
        self.exploreButton?.isEnabled = true
    }
    
    func updateContentText(text: String) {
        self.resultView?.string = text
    }
}
