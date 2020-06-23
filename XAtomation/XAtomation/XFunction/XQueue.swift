//
//  XQueue.swift
//  XAtomation
//
//  Created by 谢鸿标 on 2020/2/4.
//  Copyright © 2020 谢鸿标. All rights reserved.
//

import Foundation

func XAsyncExecute<T>(_ subBlock: @escaping ()->T, mainBlock: @escaping (T)->Void) {
    DispatchQueue.global().async {
        let t = subBlock()
        DispatchQueue.main.async {
            mainBlock(t)
        }
    }
}
