//
//  Bullshit.swift
//  BullshitFreeSpeech
//
//  Created by Jan on 22/11/2017.
//  Copyright © 2017 schwarja. All rights reserved.
//

import Foundation

struct Bullshit {
    let length: Int
    let tokens: [String]
}

class BullshitManager {
    
    static let list = [
        "very",
        "never heard",
        "heard",
        "was",
        "alarm",
        "of course"
    ]
    
    class func loadBullshits() -> [Bullshit] {
        var result = [Bullshit]()
        
        for phrase in list {
            let tokens = phrase.split(separator: " ").map({ String($0) })
            result.append(Bullshit(length: tokens.count, tokens: tokens))
        }
        
        return result
    }
}
