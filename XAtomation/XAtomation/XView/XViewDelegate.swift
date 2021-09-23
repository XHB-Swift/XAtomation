//
//  XViewDelegate.swift
//  XAtomation
//
//  Created by 谢鸿标 on 2020/3/26.
//  Copyright © 2020 谢鸿标. All rights reserved.
//

import Cocoa

protocol XDragDelegate: AnyObject {
    
    func dragView(view: NSView, didDragFilePath filePath: String)
    func dragView(view: NSView, didSelectTargetAtIndex index: Int)
}

protocol XLoadingDelegate: AnyObject {
    
    func startLoading()
    func stopLoading()
}

