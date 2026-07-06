//
//  StopService.swift
//  TripFlow
//
//  Created by Vu Minh Khoi Ha on 06.07.26.
//

import Foundation

enum StopValidationError: Error, Equatable {
    case emptyTitle
}

struct StopService {
    func createStop(
        title: String,
        locationName: String,
        scheduledDate: Date? = nil,
        for trip: Trip
    ) throws -> Stop {
        let values = try validate(title: title, locationName: locationName)

        let stop = Stop(
            title: values.title,
            locationName: values.locationName,
            scheduledDate: scheduledDate,
            orderIndex: trip.stops.count,
            trip: trip
        )

        trip.stops.append(stop)
        trip.updatedAt = Date()

        return stop
    }

    func updateStop(_ stop: Stop, title: String, locationName: String, scheduledDate: Date?) throws {
        let values = try validate(title: title, locationName: locationName)

        stop.title = values.title
        stop.locationName = values.locationName
        stop.scheduledDate = scheduledDate
        stop.updatedAt = Date()
        stop.trip?.updatedAt = Date()
    }

    private func validate(title: String, locationName: String) throws -> (title: String, locationName: String) {
        let normalizedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedLocationName = locationName.trimmingCharacters(in: .whitespacesAndNewlines)

        guard normalizedTitle.isEmpty == false else {
            throw StopValidationError.emptyTitle
        }

        return (normalizedTitle, normalizedLocationName)
    }
}
