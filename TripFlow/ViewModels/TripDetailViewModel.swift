//
//  TripDetailViewModel.swift
//  TripFlow
//
//  Created by Vu Minh Khoi Ha on 06.07.26.
//

import Foundation
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
    var isShowingCreateStop = false
    var stopErrorMessage: String?

    var canSave: Bool {
        title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    }

    var canCreateStop: Bool {
        newStopTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    }

    private let tripService: TripService
    private let stopService: StopService

    init(
        trip: Trip,
        tripService: TripService = TripService(),
        stopService: StopService = StopService()
    ) {
        title = trip.title
        startDate = trip.startDate
        endDate = trip.endDate
        hasStartDate = trip.startDate != nil
        hasEndDate = trip.endDate != nil
        self.tripService = tripService
        self.stopService = stopService
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
        trip.stops.sorted { first, second in
            first.orderIndex < second.orderIndex
        }
    }

    func showCreateStop() {
        newStopTitle = ""
        newStopLocationName = ""
        stopErrorMessage = nil
        isShowingCreateStop = true
    }

    func createStop(for trip: Trip, in modelContext: ModelContext) {
        do {
            let stop = try stopService.createStop(
                title: newStopTitle,
                locationName: newStopLocationName,
                for: trip
            )
            modelContext.insert(stop)
            newStopTitle = ""
            newStopLocationName = ""
            stopErrorMessage = nil
            isShowingCreateStop = false
        } catch StopValidationError.emptyTitle {
            stopErrorMessage = "Bitte gib einen Namen fuer den Stop ein."
        } catch {
            stopErrorMessage = "Der Stop konnte nicht erstellt werden."
        }
    }

    func deleteStops(_ stops: [Stop], at offsets: IndexSet, from trip: Trip, in modelContext: ModelContext) {
        for index in offsets {
            modelContext.delete(stops[index])
        }

        trip.updatedAt = Date()
    }
}
