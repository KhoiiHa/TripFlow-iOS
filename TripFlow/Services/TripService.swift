//
//  TripService.swift
//  TripFlow
//
//  Created by Vu Minh Khoi Ha on 05.07.26.
//

import Foundation

enum TripValidationError: Error, Equatable {
    case emptyTitle
    case endDateBeforeStartDate
}

struct TripService {
    func createTrip(title: String, startDate: Date? = nil, endDate: Date? = nil) throws -> Trip {
        let normalizedTitle = try validate(title: title, startDate: startDate, endDate: endDate)

        return Trip(title: normalizedTitle, startDate: startDate, endDate: endDate)
    }

    func updateTrip(_ trip: Trip, title: String, startDate: Date?, endDate: Date?) throws {
        let normalizedTitle = try validate(title: title, startDate: startDate, endDate: endDate)

        trip.title = normalizedTitle
        trip.startDate = startDate
        trip.endDate = endDate
        trip.updatedAt = Date()
    }

    private func validate(title: String, startDate: Date?, endDate: Date?) throws -> String {
        let normalizedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)

        guard normalizedTitle.isEmpty == false else {
            throw TripValidationError.emptyTitle
        }

        if let startDate, let endDate, endDate < startDate {
            throw TripValidationError.endDateBeforeStartDate
        }

        return normalizedTitle
    }
}
