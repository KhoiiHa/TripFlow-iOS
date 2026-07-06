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

    func region(for mapStops: [MapStop]) -> MKCoordinateRegion {
        guard let firstStop = mapStops.first else {
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 0, longitude: 0),
                span: MKCoordinateSpan(latitudeDelta: 1, longitudeDelta: 1)
            )
        }

        guard mapStops.count > 1 else {
            return MKCoordinateRegion(
                center: firstStop.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
            )
        }

        let latitudes = mapStops.map(\.coordinate.latitude)
        let longitudes = mapStops.map(\.coordinate.longitude)
        let minLatitude = latitudes.min() ?? firstStop.coordinate.latitude
        let maxLatitude = latitudes.max() ?? firstStop.coordinate.latitude
        let minLongitude = longitudes.min() ?? firstStop.coordinate.longitude
        let maxLongitude = longitudes.max() ?? firstStop.coordinate.longitude

        let center = CLLocationCoordinate2D(
            latitude: (minLatitude + maxLatitude) / 2,
            longitude: (minLongitude + maxLongitude) / 2
        )
        let span = MKCoordinateSpan(
            latitudeDelta: max((maxLatitude - minLatitude) * 1.4, 0.05),
            longitudeDelta: max((maxLongitude - minLongitude) * 1.4, 0.05)
        )

        return MKCoordinateRegion(center: center, span: span)
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
