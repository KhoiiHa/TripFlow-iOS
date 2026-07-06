//
//  TripDetailViewModel.swift
//  TripFlow
//
//  Created by Vu Minh Khoi Ha on 06.07.26.
//

import Foundation
import MapKit
import SwiftData

@Observable
final class TripDetailViewModel {
    var title: String
    var startDate: Date?
    var endDate: Date?
    var hasStartDate: Bool
    var hasEndDate: Bool
    var errorMessage: String?
    var newStopTitle = ""
    var newStopLocationName = ""
    var newStopLatitudeText = ""
    var newStopLongitudeText = ""
    var newStopScheduledDate: Date?
    var newStopHasScheduledDate = false
    var isShowingCreateStop = false
    var stopErrorMessage: String?
    var isResolvingNewStopCoordinates = false

    var canSave: Bool {
        title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    }

    var canCreateStop: Bool {
        newStopTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    }

    private let tripService: TripService
    private let stopService: StopService
    private let timelineService: TimelineService
    private let mapService: MapService
    private let geocodingService: any LocationGeocoding

    init(
        trip: Trip,
        tripService: TripService = TripService(),
        stopService: StopService = StopService(),
        timelineService: TimelineService = TimelineService(),
        mapService: MapService = MapService(),
        geocodingService: any LocationGeocoding = LocationGeocodingService()
    ) {
        title = trip.title
        startDate = trip.startDate
        endDate = trip.endDate
        hasStartDate = trip.startDate != nil
        hasEndDate = trip.endDate != nil
        self.tripService = tripService
        self.stopService = stopService
        self.timelineService = timelineService
        self.mapService = mapService
        self.geocodingService = geocodingService
    }

    func setStartDateEnabled(_ isEnabled: Bool) {
        hasStartDate = isEnabled
        startDate = isEnabled ? (startDate ?? Date()) : nil
    }

    func setEndDateEnabled(_ isEnabled: Bool) {
        hasEndDate = isEnabled
        endDate = isEnabled ? (endDate ?? startDate ?? Date()) : nil
    }

    func save(trip: Trip) {
        do {
            try tripService.updateTrip(
                trip,
                title: title,
                startDate: hasStartDate ? startDate : nil,
                endDate: hasEndDate ? endDate : nil
            )
            errorMessage = nil
        } catch TripValidationError.emptyTitle {
            errorMessage = "Bitte gib einen Namen fuer den Trip ein."
        } catch TripValidationError.endDateBeforeStartDate {
            errorMessage = "Das Enddatum darf nicht vor dem Startdatum liegen."
        } catch {
            errorMessage = "Der Trip konnte nicht gespeichert werden."
        }
    }

    func sortedStops(for trip: Trip) -> [Stop] {
        timelineService.sortedStops(for: trip)
    }

    func timeline(for trip: Trip) -> Timeline {
        timelineService.makeTimeline(for: trip)
    }

    func stopSubtitle(for stop: Stop) -> String? {
        var details: [String] = []

        if stop.locationName.isEmpty == false {
            details.append(stop.locationName)
        }

        if let scheduledDate = stop.scheduledDate {
            details.append(scheduledDate.formatted(.dateTime.day().month().year().hour().minute()))
        }

        return details.isEmpty ? nil : details.joined(separator: " - ")
    }

    func timelineDayTitle(for day: TimelineDay) -> String {
        day.date.formatted(.dateTime.weekday(.wide).day().month().year())
    }

    func timelineTimeTitle(for stop: Stop) -> String? {
        stop.scheduledDate?.formatted(.dateTime.hour().minute())
    }

    func mapStops(for trip: Trip) -> [MapStop] {
        mapService.mapStops(for: trip)
    }

    func mapRegion(for mapStops: [MapStop]) -> MKCoordinateRegion {
        mapService.region(for: mapStops)
    }

    func showCreateStop() {
        newStopTitle = ""
        newStopLocationName = ""
        newStopLatitudeText = ""
        newStopLongitudeText = ""
        newStopScheduledDate = startDate ?? Date()
        newStopHasScheduledDate = false
        stopErrorMessage = nil
        isResolvingNewStopCoordinates = false
        isShowingCreateStop = true
    }

    func setNewStopScheduledDateEnabled(_ isEnabled: Bool) {
        newStopHasScheduledDate = isEnabled
        newStopScheduledDate = isEnabled ? (newStopScheduledDate ?? startDate ?? Date()) : nil
    }

    func createStop(for trip: Trip, in modelContext: ModelContext) {
        do {
            let coordinates = try stopService.coordinates(
                latitudeText: newStopLatitudeText,
                longitudeText: newStopLongitudeText
            )
            let stop = try stopService.createStop(
                title: newStopTitle,
                locationName: newStopLocationName,
                scheduledDate: newStopHasScheduledDate ? newStopScheduledDate : nil,
                latitude: coordinates.latitude,
                longitude: coordinates.longitude,
                for: trip
            )
            modelContext.insert(stop)
            newStopTitle = ""
            newStopLocationName = ""
            newStopLatitudeText = ""
            newStopLongitudeText = ""
            newStopScheduledDate = nil
            newStopHasScheduledDate = false
            stopErrorMessage = nil
            isShowingCreateStop = false
        } catch StopValidationError.emptyTitle {
            stopErrorMessage = "Bitte gib einen Namen fuer den Stop ein."
        } catch StopValidationError.invalidCoordinates {
            stopErrorMessage = "Bitte gib gueltige Koordinaten ein."
        } catch {
            stopErrorMessage = "Der Stop konnte nicht erstellt werden."
        }
    }

    func fillNewStopCoordinatesFromLocationName() async {
        isResolvingNewStopCoordinates = true
        defer { isResolvingNewStopCoordinates = false }

        do {
            let coordinate = try await geocodingService.coordinate(for: newStopLocationName)
            newStopLatitudeText = Self.coordinateText(coordinate.latitude)
            newStopLongitudeText = Self.coordinateText(coordinate.longitude)
            stopErrorMessage = nil
        } catch LocationGeocodingError.emptyQuery {
            stopErrorMessage = "Bitte gib zuerst einen Ort ein."
        } catch {
            stopErrorMessage = "Fuer diesen Ort wurden keine Koordinaten gefunden."
        }
    }

    func deleteStops(_ stops: [Stop], at offsets: IndexSet, from trip: Trip, in modelContext: ModelContext) {
        for index in offsets {
            modelContext.delete(stops[index])
        }

        trip.updatedAt = Date()
    }

    private static func coordinateText(_ coordinate: Double) -> String {
        String(coordinate)
    }
}
