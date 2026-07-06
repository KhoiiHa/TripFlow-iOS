//
//  TripFlowTests.swift
//  TripFlowTests
//
//  Created by Vu Minh Khoi Ha on 05.07.26.
//

import Foundation
import Testing
@testable import TripFlow

struct TripFlowTests {
    private let tripService = TripService()
    private let stopService = StopService()

    @Test func createTripTrimsTitle() throws {
        let trip = try tripService.createTrip(title: "  Berlin 2026  ")

        #expect(trip.title == "Berlin 2026")
    }

    @Test func createTripRejectsEmptyTitle() {
        #expect(throws: TripValidationError.emptyTitle) {
            try tripService.createTrip(title: "   ")
        }
    }

    @Test func createTripRejectsEndDateBeforeStartDate() {
        let startDate = Date(timeIntervalSince1970: 2)
        let endDate = Date(timeIntervalSince1970: 1)

        #expect(throws: TripValidationError.endDateBeforeStartDate) {
            try tripService.createTrip(title: "Berlin", startDate: startDate, endDate: endDate)
        }
    }

    @Test func updateTripAppliesValidatedValues() throws {
        let trip = try tripService.createTrip(title: "Berlin")
        let startDate = Date(timeIntervalSince1970: 1)
        let endDate = Date(timeIntervalSince1970: 2)

        try tripService.updateTrip(
            trip,
            title: "  Paris  ",
            startDate: startDate,
            endDate: endDate
        )

        #expect(trip.title == "Paris")
        #expect(trip.startDate == startDate)
        #expect(trip.endDate == endDate)
    }

    @Test func updateTripRejectsInvalidDateRange() throws {
        let trip = try tripService.createTrip(title: "Berlin")
        let startDate = Date(timeIntervalSince1970: 2)
        let endDate = Date(timeIntervalSince1970: 1)

        #expect(throws: TripValidationError.endDateBeforeStartDate) {
            try tripService.updateTrip(
                trip,
                title: "Berlin",
                startDate: startDate,
                endDate: endDate
            )
        }
    }

    @Test func createStopTrimsTitleAndLocation() throws {
        let trip = try tripService.createTrip(title: "Berlin")

        let stop = try stopService.createStop(
            title: "  Hotel  ",
            locationName: "  Mitte  ",
            for: trip
        )

        #expect(stop.title == "Hotel")
        #expect(stop.locationName == "Mitte")
        #expect(stop.orderIndex == 0)
        #expect(stop.trip === trip)
        #expect(trip.stops.contains { $0 === stop })
    }

    @Test func createStopRejectsEmptyTitle() throws {
        let trip = try tripService.createTrip(title: "Berlin")

        #expect(throws: StopValidationError.emptyTitle) {
            try stopService.createStop(title: "   ", locationName: "Airport", for: trip)
        }
    }

    @Test func createStopKeepsInsertionOrder() throws {
        let trip = try tripService.createTrip(title: "Berlin")

        let firstStop = try stopService.createStop(title: "Hotel", locationName: "", for: trip)
        let secondStop = try stopService.createStop(title: "Museum", locationName: "", for: trip)

        #expect(firstStop.orderIndex == 0)
        #expect(secondStop.orderIndex == 1)
    }
}
