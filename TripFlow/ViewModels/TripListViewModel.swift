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
    var newTripHasStartDate = false
    var newTripStartDate = Date()
    var newTripHasEndDate = false
    var newTripEndDate = Date()
    var isShowingCreateTrip = false
    var errorMessage: String?

    var canCreateTrip: Bool {
        createTripDisabledReason == nil
    }

    var createTripDisabledReason: String? {
        if newTripTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Name fuer den Trip fehlt."
        }

        if let startDate = newTripSelectedStartDate,
           let endDate = newTripSelectedEndDate,
           endDate < startDate {
            return "Das Enddatum darf nicht vor dem Startdatum liegen."
        }

        return nil
    }

    private var newTripSelectedStartDate: Date? {
        newTripHasStartDate ? newTripStartDate : nil
    }

    private var newTripSelectedEndDate: Date? {
        newTripHasEndDate ? newTripEndDate : nil
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
        newTripHasStartDate = false
        newTripStartDate = Date()
        newTripHasEndDate = false
        newTripEndDate = Date()
        errorMessage = nil
        isShowingCreateTrip = true
    }

    func cancelCreateTrip() {
        newTripTitle = ""
        newTripHasStartDate = false
        newTripStartDate = Date()
        newTripHasEndDate = false
        newTripEndDate = Date()
        errorMessage = nil
        isShowingCreateTrip = false
    }

    func createTrip(in modelContext: ModelContext) {
        do {
            let trip = try tripService.createTrip(
                title: newTripTitle,
                startDate: newTripSelectedStartDate,
                endDate: newTripSelectedEndDate
            )
            modelContext.insert(trip)
            newTripTitle = ""
            newTripHasStartDate = false
            newTripStartDate = Date()
            newTripHasEndDate = false
            newTripEndDate = Date()
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
