//
//  LocationGeocodingService.swift
//  TripFlow
//
//  Created by Vu Minh Khoi Ha on 06.07.26.
//

import Foundation
import MapKit

struct GeocodedCoordinate: Equatable {
    let latitude: Double
    let longitude: Double
}

enum LocationGeocodingError: Error, Equatable {
    case emptyQuery
    case notFound
}

protocol LocationGeocoding {
    func coordinate(for query: String) async throws -> GeocodedCoordinate
}

struct LocationGeocodingService: LocationGeocoding {
    func coordinate(for query: String) async throws -> GeocodedCoordinate {
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)

        guard normalizedQuery.isEmpty == false else {
            throw LocationGeocodingError.emptyQuery
        }

        guard let request = MKGeocodingRequest(addressString: normalizedQuery) else {
            throw LocationGeocodingError.notFound
        }

        guard let coordinate = try await request.mapItems.first?.location.coordinate else {
            throw LocationGeocodingError.notFound
        }

        return GeocodedCoordinate(
            latitude: coordinate.latitude,
            longitude: coordinate.longitude
        )
    }
}
