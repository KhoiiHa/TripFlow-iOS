//
//  Stop.swift
//  TripFlow
//
//  Created by Vu Minh Khoi Ha on 06.07.26.
//

import Foundation
import SwiftData

@Model
final class Stop {
    var title: String
    var locationName: String
    var scheduledDate: Date?
    var latitude: Double?
    var longitude: Double?
    var orderIndex: Int
    var createdAt: Date
    var updatedAt: Date
    var trip: Trip?

    init(
        title: String,
        locationName: String = "",
        scheduledDate: Date? = nil,
        latitude: Double? = nil,
        longitude: Double? = nil,
        orderIndex: Int = 0,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        trip: Trip? = nil
    ) {
        self.title = title
        self.locationName = locationName
        self.scheduledDate = scheduledDate
        self.latitude = latitude
        self.longitude = longitude
        self.orderIndex = orderIndex
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.trip = trip
    }
}
