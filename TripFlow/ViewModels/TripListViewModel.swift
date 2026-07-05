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
        newTripTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    }

    private let tripService: TripService

    init(tripService: TripService = TripService()) {
        self.tripService = tripService
    }

    func showCreateTrip() {
        newTripTitle = ""
        errorMessage = nil
        isShowingCreateTrip = true
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
}
