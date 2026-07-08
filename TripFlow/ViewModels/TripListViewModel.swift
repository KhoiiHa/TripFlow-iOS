//
//  TripListViewModel.swift
//  TripFlow
//
//  Created by Vu Minh Khoi Ha on 05.07.26.
//

import Foundation
import SwiftData

@Observable
final class TripListViewModel {
    var newTripTitle = ""
    var isShowingCreateTrip = false
    var errorMessage: String?

    var canCreateTrip: Bool {
        createTripDisabledReason == nil
    }

    var createTripDisabledReason: String? {
        if newTripTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Name fuer den Trip fehlt."
        }

        return nil
    }

    private let tripService: TripService
    private let planningStatusService: TripPlanningStatusService

    init(
        tripService: TripService = TripService(),
        planningStatusService: TripPlanningStatusService = TripPlanningStatusService()
    ) {
        self.tripService = tripService
        self.planningStatusService = planningStatusService
    }

    func showCreateTrip() {
        newTripTitle = ""
        errorMessage = nil
        isShowingCreateTrip = true
    }

    func cancelCreateTrip() {
        newTripTitle = ""
        errorMessage = nil
        isShowingCreateTrip = false
    }

    func createTrip(in modelContext: ModelContext) {
        do {
            let trip = try tripService.createTrip(title: newTripTitle)
            modelContext.insert(trip)
            newTripTitle = ""
            errorMessage = nil
            isShowingCreateTrip = false
        } catch TripValidationError.emptyTitle {
            errorMessage = "Bitte gib einen Namen fuer den Trip ein."
        } catch TripValidationError.endDateBeforeStartDate {
            errorMessage = "Das Enddatum darf nicht vor dem Startdatum liegen."
        } catch {
            errorMessage = "Der Trip konnte nicht erstellt werden."
        }
    }

    func deleteTrips(_ trips: [Trip], at offsets: IndexSet, in modelContext: ModelContext) {
        for index in offsets {
            modelContext.delete(trips[index])
        }
    }

    func dateSummary(for trip: Trip) -> String {
        planningSummary(for: trip).dateRangeText
    }

    func planningSummary(for trip: Trip) -> TripPlanningSummary {
        planningStatusService.summary(for: trip)
    }
}
