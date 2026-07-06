//
//  StopDetailViewModel.swift
//  TripFlow
//
//  Created by Vu Minh Khoi Ha on 06.07.26.
//

import Foundation

@Observable
final class StopDetailViewModel {
    var title: String
    var locationName: String
    var latitudeText: String
    var longitudeText: String
    var scheduledDate: Date?
    var hasScheduledDate: Bool
    var errorMessage: String?
    var isResolvingCoordinates = false

    var canSave: Bool {
        title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    }

    private let stopService: StopService
    private let geocodingService: any LocationGeocoding

    init(
        stop: Stop,
        stopService: StopService = StopService(),
        geocodingService: any LocationGeocoding = LocationGeocodingService()
    ) {
        title = stop.title
        locationName = stop.locationName
        latitudeText = Self.coordinateText(stop.latitude)
        longitudeText = Self.coordinateText(stop.longitude)
        scheduledDate = stop.scheduledDate
        hasScheduledDate = stop.scheduledDate != nil
        self.stopService = stopService
        self.geocodingService = geocodingService
    }

    func setScheduledDateEnabled(_ isEnabled: Bool) {
        hasScheduledDate = isEnabled
        scheduledDate = isEnabled ? (scheduledDate ?? Date()) : nil
    }

    func save(stop: Stop) {
        do {
            let coordinates = try stopService.coordinates(
                latitudeText: latitudeText,
                longitudeText: longitudeText
            )
            try stopService.updateStop(
                stop,
                title: title,
                locationName: locationName,
                scheduledDate: hasScheduledDate ? scheduledDate : nil,
                latitude: coordinates.latitude,
                longitude: coordinates.longitude,
                updateCoordinates: true
            )
            errorMessage = nil
        } catch StopValidationError.emptyTitle {
            errorMessage = "Bitte gib einen Namen fuer den Stop ein."
        } catch StopValidationError.invalidCoordinates {
            errorMessage = "Bitte gib gueltige Koordinaten ein."
        } catch {
            errorMessage = "Der Stop konnte nicht gespeichert werden."
        }
    }

    func fillCoordinatesFromLocationName() async {
        isResolvingCoordinates = true
        defer { isResolvingCoordinates = false }

        do {
            let coordinate = try await geocodingService.coordinate(for: locationName)
            latitudeText = Self.coordinateText(coordinate.latitude)
            longitudeText = Self.coordinateText(coordinate.longitude)
            errorMessage = nil
        } catch LocationGeocodingError.emptyQuery {
            errorMessage = "Bitte gib zuerst einen Ort ein."
        } catch {
            errorMessage = "Fuer diesen Ort wurden keine Koordinaten gefunden."
        }
    }

    private static func coordinateText(_ coordinate: Double?) -> String {
        guard let coordinate else {
            return ""
        }

        return String(coordinate)
    }

    private static func coordinateText(_ coordinate: Double) -> String {
        String(coordinate)
    }
}
