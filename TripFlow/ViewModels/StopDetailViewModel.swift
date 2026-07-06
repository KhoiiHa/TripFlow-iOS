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

    var canSave: Bool {
        title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    }

    private let stopService: StopService

    init(stop: Stop, stopService: StopService = StopService()) {
        title = stop.title
        locationName = stop.locationName
        latitudeText = Self.coordinateText(stop.latitude)
        longitudeText = Self.coordinateText(stop.longitude)
        scheduledDate = stop.scheduledDate
        hasScheduledDate = stop.scheduledDate != nil
        self.stopService = stopService
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

    private static func coordinateText(_ coordinate: Double?) -> String {
        guard let coordinate else {
            return ""
        }

        return String(coordinate)
    }
}
