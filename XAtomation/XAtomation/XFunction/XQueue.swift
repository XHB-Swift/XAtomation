//
//  XQueue.swift
//  XAtomation
//
//  Created by 谢鸿标 on 2020/2/4.
//  Copyright © 2020 谢鸿标. All rights reserved.
//

import Foundation

func XAsyncExecute(_ subBlock: @escaping ()->Void, mainBlock: @escaping ()->Void) {
    DispatchQueue.global().async {
        subBlock()
        DispatchQueue.main.async(execute: mainBlock)
    }
}
