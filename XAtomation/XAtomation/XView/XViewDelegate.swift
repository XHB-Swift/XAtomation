//
//  XViewDelegate.swift
//  XAtomation
//
//  Created by 谢鸿标 on 2020/3/26.
//  Copyright © 2020 谢鸿标. All rights reserved.
//

import Cocoa

protocol XDragDelegate: class {
    
    func dragView(view: NSView, didDragFilePath filePath: String)
    func dragView(view: NSView, didSelectTargetAtIndex index: Int)
}

protocol XLoadingDelegate: class {
    
    func startLoading()
    func stopLoading()
}

