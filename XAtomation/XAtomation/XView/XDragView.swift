//
//  XDragView.swift
//  XAtomation
//
//  Created by 谢鸿标 on 2020/2/3.
//  Copyright © 2020 谢鸿标. All rights reserved.
//

import Cocoa

protocol XDragViewDelegate: XDragDelegate {
    
    func popItems(in view: XDragView) -> [String]
}

class XDragView: NSView {
    
    weak var dragDelegate: XDragViewDelegate?
    
    @IBOutlet private weak var targetPopButton: NSPopUpButton?

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        self.targetPopButton?.removeAllItems()
        if let titles = self.dragDelegate?.popItems(in: self) {
            self.targetPopButton?.addItems(withTitles: titles)
        }
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
        if let draggingSource = sender.draggingSource as? XDragView, draggingSource != self {
            if let filePaths = sender.draggingPasteboard.propertyList(forType: NSPasteboard.PasteboardType.fileURL) as? [String],
                let filePath = filePaths.first {
                self.dragDelegate?.dragView(view: self, didDragFilePath: filePath)
            }
        }
        return true
    }
    
    @IBAction func fetchPathAction(_ sender: NSButton) {
        guard let window = self.window else {
            return
        }
        let panel = NSOpenPanel()
        panel.canCreateDirectories = false
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.beginSheetModal(for: window) { response in
            if response != .OK {
                return
            }
            guard let path = panel.urls.first?.path else {
                return
            }
            self.dragDelegate?.dragView(view: self, didDragFilePath: path)
            self.targetPopButton?.removeAllItems()
            if let titles = self.dragDelegate?.popItems(in: self) {
                self.targetPopButton?.addItems(withTitles: titles)
            }
            XDebugPrint(debugDescription: "导入Xcode工程", object: path)
        }
    }
    
    @IBAction func selectTargetAction(_ sender: NSPopUpButton) {
        let title = sender.title
        let index = sender.indexOfItem(withTitle: title)
        if index == 0 {
            return
        }
        self.dragDelegate?.dragView(view: self, didSelectTargetAtIndex: index)
    }
}


