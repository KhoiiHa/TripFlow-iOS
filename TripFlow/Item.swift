//
//  Item.swift
//  TripFlow
//
//  Created by Vu Minh Khoi Ha on 05.07.26.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
