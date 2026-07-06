//
//  StopService.swift
//  TripFlow
//
//  Created by Vu Minh Khoi Ha on 06.07.26.
//

import Foundation

enum StopValidationError: Error, Equatable {
    case emptyTitle
    case invalidCoordinates
}

struct StopService {
    func createStop(
        title: String,
        locationName: String,
        scheduledDate: Date? = nil,
        latitude: Double? = nil,
        longitude: Double? = nil,
        for trip: Trip
    ) throws -> Stop {
        let values = try validate(title: title, locationName: locationName)
        let coordinates = try validateCoordinates(latitude: latitude, longitude: longitude)

        let stop = Stop(
            title: values.title,
            locationName: values.locationName,
            scheduledDate: scheduledDate,
            latitude: coordinates.latitude,
            longitude: coordinates.longitude,
            orderIndex: trip.stops.count,
            trip: trip
        )

        trip.stops.append(stop)
        trip.updatedAt = Date()

        return stop
    }

    func updateStop(
        _ stop: Stop,
        title: String,
        locationName: String,
        scheduledDate: Date?,
        latitude: Double? = nil,
        longitude: Double? = nil,
        updateCoordinates: Bool = false
    ) throws {
        let values = try validate(title: title, locationName: locationName)
        let coordinates = try validateCoordinates(latitude: latitude, longitude: longitude)

        stop.title = values.title
        stop.locationName = values.locationName
        stop.scheduledDate = scheduledDate

        if updateCoordinates {
            stop.latitude = coordinates.latitude
            stop.longitude = coordinates.longitude
        } else {
            if let latitude = coordinates.latitude {
                stop.latitude = latitude
            }

            if let longitude = coordinates.longitude {
                stop.longitude = longitude
            }
        }

        stop.updatedAt = Date()
        stop.trip?.updatedAt = Date()
    }

    func coordinates(latitudeText: String, longitudeText: String) throws -> (latitude: Double?, longitude: Double?) {
        let latitude = try parseCoordinate(latitudeText)
        let longitude = try parseCoordinate(longitudeText)

        return try validateCoordinates(latitude: latitude, longitude: longitude)
    }

    private func validate(title: String, locationName: String) throws -> (title: String, locationName: String) {
        let normalizedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedLocationName = locationName.trimmingCharacters(in: .whitespacesAndNewlines)

        guard normalizedTitle.isEmpty == false else {
            throw StopValidationError.emptyTitle
        }

        return (normalizedTitle, normalizedLocationName)
    }

    private func parseCoordinate(_ text: String) throws -> Double? {
        let normalizedText = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: ".")

        guard normalizedText.isEmpty == false else {
            return nil
        }

        guard let value = Double(normalizedText) else {
            throw StopValidationError.invalidCoordinates
        }

        return value
    }

    private func validateCoordinates(latitude: Double?, longitude: Double?) throws -> (latitude: Double?, longitude: Double?) {
        switch (latitude, longitude) {
        case (nil, nil):
            return (nil, nil)
        case let (latitude?, longitude?):
            guard (-90...90).contains(latitude), (-180...180).contains(longitude) else {
                throw StopValidationError.invalidCoordinates
            }

            return (latitude, longitude)
        default:
            throw StopValidationError.invalidCoordinates
        }
    }
}
