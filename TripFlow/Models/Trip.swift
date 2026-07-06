//
//  Trip.swift
//  TripFlow
//
//  Created by Vu Minh Khoi Ha on 05.07.26.
//

import Foundation
import SwiftData

@Model
final class Trip {
    var title: String
    var startDate: Date?
    var endDate: Date?
    var createdAt: Date
    var updatedAt: Date
    @Relationship(deleteRule: .cascade, inverse: \Stop.trip)
    var stops: [Stop]

    init(
        title: String,
        startDate: Date? = nil,
        endDate: Date? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        stops: [Stop] = []
    ) {
        self.title = title
        self.startDate = startDate
        self.endDate = endDate
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.stops = stops
    }
}
