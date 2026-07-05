//
//  TripDetailViewModel.swift
//  TripFlow
//
//  Created by Vu Minh Khoi Ha on 06.07.26.
//

import Foundation

@Observable
final class TripDetailViewModel {
    var title: String
    var startDate: Date?
    var endDate: Date?
    var hasStartDate: Bool
    var hasEndDate: Bool
    var errorMessage: String?

    var canSave: Bool {
        title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    }

    private let tripService: TripService

    init(trip: Trip, tripService: TripService = TripService()) {
        title = trip.title
        startDate = trip.startDate
        endDate = trip.endDate
        hasStartDate = trip.startDate != nil
        hasEndDate = trip.endDate != nil
        self.tripService = tripService
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
}
