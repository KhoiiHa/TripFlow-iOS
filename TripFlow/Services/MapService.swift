//
//  MapService.swift
//  TripFlow
//
//  Created by Vu Minh Khoi Ha on 06.07.26.
//

import Foundation
import MapKit

struct MapStop: Identifiable {
    let id: String
    let title: String
    let locationName: String
    let coordinate: CLLocationCoordinate2D
}

struct MapService {
    func mapStops(for trip: Trip) -> [MapStop] {
        trip.stops
            .sorted { $0.orderIndex < $1.orderIndex }
            .compactMap(makeMapStop)
    }

    private func makeMapStop(from stop: Stop) -> MapStop? {
        guard let latitude = stop.latitude, let longitude = stop.longitude else {
            return nil
        }

        let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)

        guard CLLocationCoordinate2DIsValid(coordinate) else {
            return nil
        }

        return MapStop(
            id: "\(stop.orderIndex)-\(stop.title)-\(latitude)-\(longitude)",
            title: stop.title,
            locationName: stop.locationName,
            coordinate: coordinate
        )
    }
}
