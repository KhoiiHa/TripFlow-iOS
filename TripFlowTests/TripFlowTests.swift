//
//  TripFlowTests.swift
//  TripFlowTests
//
//  Created by Vu Minh Khoi Ha on 05.07.26.
//

import Foundation
import MapKit
import Testing
@testable import TripFlow

struct TripFlowTests {
    private let tripService = TripService()
    private let stopService = StopService()
    private let timelineService = TimelineService()
    private let mapService = MapService()
    private let travelDocumentService = TravelDocumentService()

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

    @Test func createTravelDocumentTrimsValuesAndAssignsTrip() throws {
        let trip = try tripService.createTrip(title: "Berlin")

        let document = try travelDocumentService.createDocument(
            title: "  Hotel Booking  ",
            documentType: "  Hotel  ",
            fileName: "  booking.pdf  ",
            extractedText: "  Check-in 15:00  ",
            for: trip
        )

        #expect(document.title == "Hotel Booking")
        #expect(document.documentType == "Hotel")
        #expect(document.fileName == "booking.pdf")
        #expect(document.extractedText == "Check-in 15:00")
        #expect(document.trip === trip)
        #expect(trip.documents.contains { $0 === document })
    }

    @Test func createTravelDocumentRejectsEmptyTitle() throws {
        let trip = try tripService.createTrip(title: "Berlin")

        #expect(throws: TravelDocumentValidationError.emptyTitle) {
            try travelDocumentService.createDocument(title: "   ", for: trip)
        }
    }

    @Test func updateTravelDocumentAppliesValidatedValues() throws {
        let trip = try tripService.createTrip(title: "Berlin")
        let document = try travelDocumentService.createDocument(title: "Ticket", for: trip)

        try travelDocumentService.updateDocument(
            document,
            title: "  Train Ticket  ",
            documentType: "  Ticket  ",
            fileName: "  train.pdf  ",
            extractedText: "  ICE 100  "
        )

        #expect(document.title == "Train Ticket")
        #expect(document.documentType == "Ticket")
        #expect(document.fileName == "train.pdf")
        #expect(document.extractedText == "ICE 100")
    }

    @Test func applyExtractedTextTrimsText() throws {
        let trip = try tripService.createTrip(title: "Berlin")
        let document = try travelDocumentService.createDocument(title: "Ticket", for: trip)

        travelDocumentService.applyExtractedText("  Gate A12  ", to: document)

        #expect(document.extractedText == "Gate A12")
    }

    @Test func tripDetailSortsDocumentsNewestFirst() throws {
        let trip = try tripService.createTrip(title: "Berlin")
        let olderDocument = TravelDocument(
            title: "Hotel",
            createdAt: Date(timeIntervalSince1970: 1),
            trip: trip
        )
        let newerDocument = TravelDocument(
            title: "Ticket",
            createdAt: Date(timeIntervalSince1970: 2),
            trip: trip
        )
        trip.documents = [olderDocument, newerDocument]
        let viewModel = TripDetailViewModel(trip: trip)

        let documents = viewModel.sortedDocuments(for: trip)

        #expect(documents.map(\.title) == ["Ticket", "Hotel"])
    }

    @Test func tripDetailDocumentSubtitleUsesTypeAndFileName() throws {
        let trip = try tripService.createTrip(title: "Berlin")
        let document = try travelDocumentService.createDocument(
            title: "Hotel",
            documentType: "Booking",
            fileName: "hotel.pdf",
            for: trip
        )
        let viewModel = TripDetailViewModel(trip: trip)

        #expect(viewModel.documentSubtitle(for: document) == "Booking - hotel.pdf")
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

    @Test func createStopAppliesScheduledDate() throws {
        let trip = try tripService.createTrip(title: "Berlin")
        let scheduledDate = Date(timeIntervalSince1970: 1)

        let stop = try stopService.createStop(
            title: "Hotel",
            locationName: "",
            scheduledDate: scheduledDate,
            for: trip
        )

        #expect(stop.scheduledDate == scheduledDate)
    }

    @Test func createStopAppliesCoordinates() throws {
        let trip = try tripService.createTrip(title: "Berlin")

        let stop = try stopService.createStop(
            title: "Hotel",
            locationName: "",
            latitude: 52.52,
            longitude: 13.405,
            for: trip
        )

        #expect(stop.latitude == 52.52)
        #expect(stop.longitude == 13.405)
    }

    @Test func coordinateInputParsesDecimalComma() throws {
        let coordinates = try stopService.coordinates(
            latitudeText: "52,52",
            longitudeText: "13,405"
        )

        #expect(coordinates.latitude == 52.52)
        #expect(coordinates.longitude == 13.405)
    }

    @Test func coordinateInputAllowsEmptyCoordinates() throws {
        let coordinates = try stopService.coordinates(latitudeText: "", longitudeText: "   ")

        #expect(coordinates.latitude == nil)
        #expect(coordinates.longitude == nil)
    }

    @Test func coordinateInputRejectsPartialCoordinates() {
        #expect(throws: StopValidationError.invalidCoordinates) {
            try stopService.coordinates(latitudeText: "52.52", longitudeText: "")
        }
    }

    @Test func coordinateInputRejectsOutOfRangeCoordinates() {
        #expect(throws: StopValidationError.invalidCoordinates) {
            try stopService.coordinates(latitudeText: "120", longitudeText: "13.405")
        }
    }

    @Test func createStopRejectsInvalidCoordinates() throws {
        let trip = try tripService.createTrip(title: "Berlin")

        #expect(throws: StopValidationError.invalidCoordinates) {
            try stopService.createStop(
                title: "Hotel",
                locationName: "",
                latitude: 52.52,
                longitude: nil,
                for: trip
            )
        }
    }

    @Test func updateStopAppliesValidatedValues() throws {
        let trip = try tripService.createTrip(title: "Berlin")
        let stop = try stopService.createStop(title: "Hotel", locationName: "Mitte", for: trip)
        let scheduledDate = Date(timeIntervalSince1970: 2)

        try stopService.updateStop(
            stop,
            title: "  Museum  ",
            locationName: "  Zentrum  ",
            scheduledDate: scheduledDate
        )

        #expect(stop.title == "Museum")
        #expect(stop.locationName == "Zentrum")
        #expect(stop.scheduledDate == scheduledDate)
    }

    @Test func updateStopAppliesCoordinates() throws {
        let trip = try tripService.createTrip(title: "Berlin")
        let stop = try stopService.createStop(title: "Hotel", locationName: "", for: trip)

        try stopService.updateStop(
            stop,
            title: "Hotel",
            locationName: "",
            scheduledDate: nil,
            latitude: 52.52,
            longitude: 13.405
        )

        #expect(stop.latitude == 52.52)
        #expect(stop.longitude == 13.405)
    }

    @Test func updateStopKeepsExistingCoordinatesWhenNoCoordinatesAreProvided() throws {
        let trip = try tripService.createTrip(title: "Berlin")
        let stop = try stopService.createStop(
            title: "Hotel",
            locationName: "",
            latitude: 52.52,
            longitude: 13.405,
            for: trip
        )

        try stopService.updateStop(
            stop,
            title: "Museum",
            locationName: "",
            scheduledDate: nil
        )

        #expect(stop.latitude == 52.52)
        #expect(stop.longitude == 13.405)
    }

    @Test func updateStopClearsCoordinatesWhenRequested() throws {
        let trip = try tripService.createTrip(title: "Berlin")
        let stop = try stopService.createStop(
            title: "Hotel",
            locationName: "",
            latitude: 52.52,
            longitude: 13.405,
            for: trip
        )

        try stopService.updateStop(
            stop,
            title: "Hotel",
            locationName: "",
            scheduledDate: nil,
            updateCoordinates: true
        )

        #expect(stop.latitude == nil)
        #expect(stop.longitude == nil)
    }

    @Test func updateStopRejectsEmptyTitle() throws {
        let trip = try tripService.createTrip(title: "Berlin")
        let stop = try stopService.createStop(title: "Hotel", locationName: "", for: trip)

        #expect(throws: StopValidationError.emptyTitle) {
            try stopService.updateStop(stop, title: "   ", locationName: "", scheduledDate: nil)
        }
    }

    @Test func timelineGroupsScheduledStopsByDay() throws {
        let trip = try tripService.createTrip(title: "Berlin")
        let calendar = testCalendar()
        let firstDayMorning = makeDate(year: 2026, month: 7, day: 6, hour: 9, minute: 0, calendar: calendar)
        let firstDayEvening = makeDate(year: 2026, month: 7, day: 6, hour: 18, minute: 0, calendar: calendar)
        let secondDay = makeDate(year: 2026, month: 7, day: 7, hour: 10, minute: 0, calendar: calendar)

        let hotel = try stopService.createStop(title: "Hotel", locationName: "", scheduledDate: firstDayMorning, for: trip)
        let dinner = try stopService.createStop(title: "Dinner", locationName: "", scheduledDate: firstDayEvening, for: trip)
        let museum = try stopService.createStop(title: "Museum", locationName: "", scheduledDate: secondDay, for: trip)

        let timeline = timelineService.makeTimeline(for: trip, calendar: calendar)

        #expect(timeline.days.count == 2)
        #expect(timeline.days[0].date == calendar.startOfDay(for: firstDayMorning))
        #expect(timeline.days[0].stops.map(\.title) == [hotel.title, dinner.title])
        #expect(timeline.days[1].date == calendar.startOfDay(for: secondDay))
        #expect(timeline.days[1].stops.map(\.title) == [museum.title])
    }

    @Test func timelineSortsScheduledStopsBeforeUnscheduledStops() throws {
        let trip = try tripService.createTrip(title: "Berlin")
        let calendar = testCalendar()
        let morning = makeDate(year: 2026, month: 7, day: 6, hour: 9, minute: 0, calendar: calendar)
        let evening = makeDate(year: 2026, month: 7, day: 6, hour: 18, minute: 0, calendar: calendar)

        let unscheduled = try stopService.createStop(title: "Packen", locationName: "", for: trip)
        let dinner = try stopService.createStop(title: "Dinner", locationName: "", scheduledDate: evening, for: trip)
        let hotel = try stopService.createStop(title: "Hotel", locationName: "", scheduledDate: morning, for: trip)

        let sortedStops = timelineService.sortedStops(for: trip, calendar: calendar)

        #expect(sortedStops.map(\.title) == [hotel.title, dinner.title, unscheduled.title])
    }

    @Test func timelineKeepsInsertionOrderForUnscheduledStops() throws {
        let trip = try tripService.createTrip(title: "Berlin")

        let hotel = try stopService.createStop(title: "Hotel", locationName: "", for: trip)
        let museum = try stopService.createStop(title: "Museum", locationName: "", for: trip)

        let timeline = timelineService.makeTimeline(for: trip, calendar: testCalendar())

        #expect(timeline.days.isEmpty)
        #expect(timeline.unscheduledStops.map(\.title) == [hotel.title, museum.title])
    }

    @Test func mapStopsIncludesStopsWithValidCoordinatesInOrder() throws {
        let trip = try tripService.createTrip(title: "Berlin")
        _ = try stopService.createStop(title: "Hotel", locationName: "Mitte", latitude: 52.52, longitude: 13.405, for: trip)
        _ = try stopService.createStop(title: "Museum", locationName: "Zentrum", latitude: 52.51, longitude: 13.39, for: trip)

        let mapStops = mapService.mapStops(for: trip)

        #expect(mapStops.map(\.title) == ["Hotel", "Museum"])
        #expect(mapStops[0].locationName == "Mitte")
        #expect(mapStops[0].coordinate.latitude == 52.52)
        #expect(mapStops[0].coordinate.longitude == 13.405)
    }

    @Test func mapStopsIgnoresStopsWithoutValidCoordinates() throws {
        let trip = try tripService.createTrip(title: "Berlin")
        _ = try stopService.createStop(title: "No Coordinates", locationName: "", for: trip)
        _ = try stopService.createStop(title: "Hotel", locationName: "", latitude: 52.52, longitude: 13.405, for: trip)
        trip.stops.append(Stop(title: "Only Latitude", latitude: 52.52, orderIndex: 2, trip: trip))
        trip.stops.append(Stop(title: "Invalid Latitude", latitude: 120, longitude: 13.405, orderIndex: 3, trip: trip))

        let mapStops = mapService.mapStops(for: trip)

        #expect(mapStops.map(\.title) == ["Hotel"])
    }

    @Test func mapRegionCoversMapStops() throws {
        let trip = try tripService.createTrip(title: "Berlin")
        _ = try stopService.createStop(title: "Hotel", locationName: "", latitude: 52.52, longitude: 13.405, for: trip)
        _ = try stopService.createStop(title: "Museum", locationName: "", latitude: 52.50, longitude: 13.35, for: trip)
        let mapStops = mapService.mapStops(for: trip)

        let region = mapService.region(for: mapStops)

        #expect(abs(region.center.latitude - 52.51) < 0.000001)
        #expect(abs(region.center.longitude - 13.3775) < 0.000001)
        #expect(region.span.latitudeDelta >= 0.05)
        #expect(region.span.longitudeDelta >= 0.05)
    }

    @Test @MainActor func tripDetailGeocodingFillsNewStopCoordinates() async {
        let trip = Trip(title: "Berlin")
        let viewModel = TripDetailViewModel(
            trip: trip,
            geocodingService: StubLocationGeocodingService(
                result: .success(GeocodedCoordinate(latitude: 52.52, longitude: 13.405))
            )
        )
        viewModel.newStopLocationName = "Berlin"

        await viewModel.fillNewStopCoordinatesFromLocationName()

        #expect(viewModel.newStopLatitudeText == "52.52")
        #expect(viewModel.newStopLongitudeText == "13.405")
        #expect(viewModel.stopErrorMessage == nil)
    }

    @Test @MainActor func stopDetailGeocodingFillsCoordinates() async {
        let stop = Stop(title: "Hotel", locationName: "Berlin")
        let viewModel = StopDetailViewModel(
            stop: stop,
            geocodingService: StubLocationGeocodingService(
                result: .success(GeocodedCoordinate(latitude: 52.52, longitude: 13.405))
            )
        )

        await viewModel.fillCoordinatesFromLocationName()

        #expect(viewModel.latitudeText == "52.52")
        #expect(viewModel.longitudeText == "13.405")
        #expect(viewModel.errorMessage == nil)
    }

    @Test @MainActor func stopDetailGeocodingShowsNotFoundError() async {
        let stop = Stop(title: "Hotel", locationName: "Unknown")
        let viewModel = StopDetailViewModel(
            stop: stop,
            geocodingService: StubLocationGeocodingService(result: .failure(LocationGeocodingError.notFound))
        )

        await viewModel.fillCoordinatesFromLocationName()

        #expect(viewModel.latitudeText.isEmpty)
        #expect(viewModel.longitudeText.isEmpty)
        #expect(viewModel.errorMessage == "Fuer diesen Ort wurden keine Koordinaten gefunden.")
    }

    private func testCalendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        return calendar
    }

    private func makeDate(
        year: Int,
        month: Int,
        day: Int,
        hour: Int,
        minute: Int,
        calendar: Calendar
    ) -> Date {
        DateComponents(
            calendar: calendar,
            timeZone: calendar.timeZone,
            year: year,
            month: month,
            day: day,
            hour: hour,
            minute: minute
        ).date ?? Date()
    }
}

private struct StubLocationGeocodingService: LocationGeocoding {
    let result: Result<GeocodedCoordinate, Error>

    func coordinate(for query: String) async throws -> GeocodedCoordinate {
        try result.get()
    }
}
