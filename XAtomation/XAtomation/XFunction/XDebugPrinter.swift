//
//  XDebugPrinter.swift
//  XAtomation
//
//  Created by 谢鸿标 on 2020/1/23.
//  Copyright © 2020 谢鸿标. All rights reserved.
//

import Foundation

protocol XDebugProtocol {
    var description: String { get }
    func debugPrint(debugDescription: String)
    func debugPrint(debugDescription: String, object: Any?)
}

extension XDebugProtocol {
    func debugPrint(debugDescription: String) {
        XDebugPrint(debugDescription: debugDescription, object: self.description)
    }
    func debugPrint(debugDescription: String, object: Any?) {
        XDebugPrint(debugDescription: debugDescription, object: object)
    }
}

func XDebugPrint(debugDescription: String, object: Any?) {
    let prefixSymbol = "------------XAtomiation \(debugDescription)------------\n"
    let date = "date: \(Date())\n"
    let suffixSymbol = "\n------------XAtomiation End----------------------------"
    let content = "content: \(object ?? String(describing: object))\(suffixSymbol)"
    print("\(prefixSymbol)\(date)\(content)")
}
