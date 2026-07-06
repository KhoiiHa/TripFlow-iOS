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
    func createStop(title: String, locationName: String, for trip: Trip) throws -> Stop {
        let normalizedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedLocationName = locationName.trimmingCharacters(in: .whitespacesAndNewlines)

        guard normalizedTitle.isEmpty == false else {
            throw StopValidationError.emptyTitle
        }

        let stop = Stop(
            title: normalizedTitle,
            locationName: normalizedLocationName,
            orderIndex: trip.stops.count,
            trip: trip
        )

        trip.stops.append(stop)
        trip.updatedAt = Date()

        return stop
    }
}
