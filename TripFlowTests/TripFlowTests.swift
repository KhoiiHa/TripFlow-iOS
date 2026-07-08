//
//  TripFlowTests.swift
//  TripFlowTests
//
//  Created by Vu Minh Khoi Ha on 05.07.26.
//

import Foundation
import MapKit
import SwiftData
import Testing
@testable import TripFlow

struct TripFlowTests {
    private let tripService = TripService()
    private let stopService = StopService()
    private let timelineService = TimelineService()
    private let mapService = MapService()
    private let travelDocumentService = TravelDocumentService()
    private let travelDocumentParserService = TravelDocumentParserService()

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

    @Test func parserExtractsDateAndTimeFromTravelDocumentText() {
        let result = travelDocumentParserService.parse(
            "Check-in 15.07.2026 ab 14:30 Uhr",
            calendar: testCalendar()
        )

        #expect(result.date == TravelDocumentParsedDate(day: 15, month: 7, year: 2026))
        #expect(result.time == TravelDocumentParsedTime(hour: 14, minute: 30))
        #expect(result.scheduledDate == makeDate(year: 2026, month: 7, day: 15, hour: 14, minute: 30, calendar: testCalendar()))
    }

    @Test func parserSupportsShortYearAndSlashDate() {
        let result = travelDocumentParserService.parse("Boarding 05/08/26 09:05")

        #expect(result.date == TravelDocumentParsedDate(day: 5, month: 8, year: 2026))
        #expect(result.time == TravelDocumentParsedTime(hour: 9, minute: 5))
    }

    @Test func parserIgnoresInvalidDateAndTimeValues() {
        let result = travelDocumentParserService.parse("Termin 40.15.2026 25:90")

        #expect(result.date == nil)
        #expect(result.time == nil)
        #expect(result.scheduledDate == nil)
    }

    @Test func parserSuggestsHotelStopTitleFromDocumentText() {
        let result = travelDocumentParserService.parse("Hotel Check-in 15.07.2026 ab 14:30 Uhr")

        #expect(result.suggestedStopTitle == "Hotel Check-in")
    }

    @Test func parserSuggestsFlightStopTitleFromDocumentText() {
        let result = travelDocumentParserService.parse("Boarding Gate A12 05/08/26 09:05")

        #expect(result.suggestedStopTitle == "Flug")
    }

    @Test func parserSuggestsLocationNameFromLabeledDocumentLine() {
        let result = travelDocumentParserService.parse(
            """
            Hotel Check-in 15.07.2026 ab 14:30 Uhr
            Adresse: Alexanderplatz 1, Berlin
            """
        )

        #expect(result.suggestedLocationName == "Alexanderplatz 1, Berlin")
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

    @Test func tripDetailPrefillsNewStopFromDocumentSchedule() throws {
        let trip = try tripService.createTrip(title: "Berlin")
        let document = try travelDocumentService.createDocument(
            title: "Importierte Unterlage",
            documentType: "Hotel",
            extractedText: """
            Check-in 15.07.2026 ab 14:30 Uhr
            Adresse: Alexanderplatz 1, Berlin
            """,
            for: trip
        )
        let viewModel = TripDetailViewModel(trip: trip)

        viewModel.showCreateStop(from: document, calendar: testCalendar())

        #expect(viewModel.newStopTitle == "Hotel Check-in")
        #expect(viewModel.newStopLocationName == "Alexanderplatz 1, Berlin")
        #expect(viewModel.newStopHasScheduledDate)
        #expect(viewModel.newStopScheduledDate == makeDate(year: 2026, month: 7, day: 15, hour: 14, minute: 30, calendar: testCalendar()))
        #expect(viewModel.isShowingCreateStop)
        #expect(viewModel.isReviewingDocumentStopSuggestion)
        #expect(viewModel.stopSuggestionDocumentType == "Hotel")
        #expect(viewModel.stopSuggestionTextExcerpt == "Check-in 15.07.2026 ab 14:30 Uhr\nAdresse: Alexanderplatz 1, Berlin")
    }

    @Test func tripDetailKeepsNewStopScheduleOffForUnparsedDocument() throws {
        let trip = try tripService.createTrip(title: "Berlin")
        let document = try travelDocumentService.createDocument(
            title: "Hotel",
            extractedText: "Importierte Unterlage ohne Datum",
            for: trip
        )
        let viewModel = TripDetailViewModel(trip: trip)

        viewModel.showCreateStop(from: document, calendar: testCalendar())

        #expect(viewModel.newStopTitle == "Hotel")
        #expect(viewModel.newStopHasScheduledDate == false)
        #expect(viewModel.isShowingCreateStop)
    }

    @Test @MainActor func tripDetailRejectsDocumentStopSuggestionWithoutDate() throws {
        let trip = try tripService.createTrip(title: "Berlin")
        let document = try travelDocumentService.createDocument(
            title: "Hotel Check-in",
            extractedText: "Check-in 15.07.2026 ab 14:30 Uhr",
            for: trip
        )
        let viewModel = TripDetailViewModel(trip: trip)
        let modelContext = try makeModelContext()
        viewModel.showCreateStop(from: document, calendar: testCalendar())
        viewModel.newStopScheduledDate = nil

        viewModel.createStop(for: trip, in: modelContext)

        #expect(trip.stops.isEmpty)
        #expect(viewModel.stopErrorMessage == "Bitte pruefe Datum und Uhrzeit fuer den vorgeschlagenen Stop.")
        #expect(viewModel.isShowingCreateStop)
    }

    @Test @MainActor func tripDetailCreatesDocumentFromSheetState() throws {
        let trip = try tripService.createTrip(title: "Berlin")
        let viewModel = TripDetailViewModel(trip: trip)
        let modelContext = try makeModelContext()
        viewModel.newDocumentTitle = "  Hotelbuchung  "
        viewModel.newDocumentType = "  Hotel  "
        viewModel.newDocumentFileName = "  hotel.pdf  "
        viewModel.newDocumentExtractedText = "  Check-in 15:00  "
        viewModel.isShowingCreateDocument = true

        viewModel.createDocument(for: trip, in: modelContext)

        #expect(trip.documents.count == 1)
        #expect(trip.documents.first?.title == "Hotelbuchung")
        #expect(trip.documents.first?.documentType == "Hotel")
        #expect(trip.documents.first?.fileName == "hotel.pdf")
        #expect(trip.documents.first?.extractedText == "Check-in 15:00")
        #expect(viewModel.newDocumentTitle.isEmpty)
        #expect(viewModel.newDocumentType.isEmpty)
        #expect(viewModel.newDocumentFileName.isEmpty)
        #expect(viewModel.newDocumentExtractedText.isEmpty)
        #expect(viewModel.documentErrorMessage == nil)
        #expect(viewModel.isShowingCreateDocument == false)
    }

    @Test @MainActor func tripDetailRejectsDocumentWithoutTitle() throws {
        let trip = try tripService.createTrip(title: "Berlin")
        let viewModel = TripDetailViewModel(trip: trip)
        let modelContext = try makeModelContext()
        viewModel.newDocumentTitle = "   "
        viewModel.isShowingCreateDocument = true

        viewModel.createDocument(for: trip, in: modelContext)

        #expect(trip.documents.isEmpty)
        #expect(viewModel.documentErrorMessage == "Bitte gib einen Namen fuer die Reiseunterlage ein.")
        #expect(viewModel.isShowingCreateDocument)
    }

    @Test @MainActor func tripDetailDeletesDocumentFromTripAndContext() throws {
        let trip = try tripService.createTrip(title: "Berlin")
        let document = try travelDocumentService.createDocument(title: "Hotelbuchung", for: trip)
        let viewModel = TripDetailViewModel(trip: trip)
        let modelContext = try makeModelContext()
        modelContext.insert(trip)
        modelContext.insert(document)

        viewModel.deleteDocuments([document], at: IndexSet(integer: 0), from: trip, in: modelContext)
        try modelContext.save()

        let documents = try modelContext.fetch(FetchDescriptor<TravelDocument>())
        #expect(trip.documents.isEmpty)
        #expect(documents.isEmpty)
    }

    @Test func documentDetailInitializesFromDocument() {
        let document = TravelDocument(
            title: "Hotelbuchung",
            documentType: "Hotel",
            fileName: "hotel.pdf",
            extractedText: "Check-in 15:00"
        )

        let viewModel = TravelDocumentDetailViewModel(document: document)

        #expect(viewModel.title == "Hotelbuchung")
        #expect(viewModel.documentType == "Hotel")
        #expect(viewModel.fileName == "hotel.pdf")
        #expect(viewModel.extractedText == "Check-in 15:00")
    }

    @Test func documentDetailParsesScheduleFromExtractedText() {
        let document = TravelDocument(
            title: "Hotel",
            extractedText: "Check-in 15.07.2026 ab 14:30 Uhr"
        )
        let viewModel = TravelDocumentDetailViewModel(document: document)

        let result = viewModel.parsedTravelDocumentResult(calendar: testCalendar())

        #expect(result.scheduledDate == makeDate(year: 2026, month: 7, day: 15, hour: 14, minute: 30, calendar: testCalendar()))
    }

    @Test func documentDetailParsesSuggestedStopTitleAndLocation() {
        let document = TravelDocument(
            title: "Hotel",
            extractedText: """
            Check-in 15.07.2026 ab 14:30 Uhr
            Adresse: Alexanderplatz 1, Berlin
            """
        )
        let viewModel = TravelDocumentDetailViewModel(document: document)

        #expect(viewModel.hasParsedTravelData(calendar: testCalendar()))
        #expect(viewModel.parsedSuggestedStopTitle(calendar: testCalendar()) == "Hotel Check-in")
        #expect(viewModel.parsedSuggestedLocationName(calendar: testCalendar()) == "Alexanderplatz 1, Berlin")
    }

    @Test func documentDetailPreparesStopSuggestionFromParsedData() throws {
        let trip = try tripService.createTrip(title: "Berlin")
        let document = try travelDocumentService.createDocument(
            title: "Importierte Unterlage",
            extractedText: """
            Check-in 15.07.2026 ab 14:30 Uhr
            Adresse: Alexanderplatz 1, Berlin
            """,
            for: trip
        )
        let viewModel = TravelDocumentDetailViewModel(document: document)

        viewModel.showStopSuggestion(from: document, calendar: testCalendar())

        #expect(viewModel.isShowingStopSuggestion)
        #expect(viewModel.stopSuggestionTitle == "Hotel Check-in")
        #expect(viewModel.stopSuggestionLocationName == "Alexanderplatz 1, Berlin")
        #expect(viewModel.stopSuggestionScheduledDate == makeDate(year: 2026, month: 7, day: 15, hour: 14, minute: 30, calendar: testCalendar()))
        #expect(viewModel.stopSuggestionDocumentType == "")
        #expect(viewModel.stopSuggestionTextExcerpt == "Check-in 15.07.2026 ab 14:30 Uhr\nAdresse: Alexanderplatz 1, Berlin")
        #expect(viewModel.canCreateStopSuggestion)
    }

    @Test func documentDetailLimitsStopSuggestionTextExcerpt() throws {
        let trip = try tripService.createTrip(title: "Berlin")
        let longText = String(repeating: "A", count: 130)
        let document = try travelDocumentService.createDocument(
            title: "Importierte Unterlage",
            documentType: "Hotel",
            extractedText: longText,
            for: trip
        )
        let viewModel = TravelDocumentDetailViewModel(document: document)

        viewModel.showStopSuggestion(from: document, calendar: testCalendar())

        #expect(viewModel.stopSuggestionDocumentType == "Hotel")
        #expect(viewModel.stopSuggestionTextExcerpt == String(repeating: "A", count: 120) + "...")
    }

    @Test @MainActor func documentDetailCreatesStopSuggestionForTrip() throws {
        let trip = try tripService.createTrip(title: "Berlin")
        let document = try travelDocumentService.createDocument(
            title: "Importierte Unterlage",
            extractedText: "Check-in 15.07.2026 ab 14:30 Uhr",
            for: trip
        )
        let viewModel = TravelDocumentDetailViewModel(document: document)
        let modelContext = try makeModelContext()
        modelContext.insert(trip)
        modelContext.insert(document)
        viewModel.showStopSuggestion(from: document, calendar: testCalendar())

        viewModel.createStopSuggestion(from: document, in: modelContext)

        #expect(trip.stops.count == 1)
        #expect(trip.stops.first?.title == "Hotel Check-in")
        #expect(trip.stops.first?.scheduledDate == makeDate(year: 2026, month: 7, day: 15, hour: 14, minute: 30, calendar: testCalendar()))
        #expect(viewModel.isShowingStopSuggestion == false)
        #expect(viewModel.stopSuggestionErrorMessage == nil)
        #expect(viewModel.stopSuggestionSuccessMessage == "Stop \"Hotel Check-in\" wurde erstellt.")
    }

    @Test @MainActor func documentDetailClearsStopSuggestionSuccessWhenReviewStartsAgain() throws {
        let trip = try tripService.createTrip(title: "Berlin")
        let document = try travelDocumentService.createDocument(
            title: "Importierte Unterlage",
            extractedText: "Check-in 15.07.2026 ab 14:30 Uhr",
            for: trip
        )
        let viewModel = TravelDocumentDetailViewModel(document: document)
        let modelContext = try makeModelContext()
        modelContext.insert(trip)
        modelContext.insert(document)
        viewModel.showStopSuggestion(from: document, calendar: testCalendar())
        viewModel.createStopSuggestion(from: document, in: modelContext)

        viewModel.showStopSuggestion(from: document, calendar: testCalendar())

        #expect(viewModel.stopSuggestionSuccessMessage == nil)
    }

    @Test func documentDetailDoesNotShowScheduleForUnparsedText() {
        let document = TravelDocument(
            title: "Hotel",
            extractedText: "Reservierung ohne Datum"
        )
        let viewModel = TravelDocumentDetailViewModel(document: document)

        #expect(viewModel.parsedScheduleText(calendar: testCalendar()) == nil)
    }

    @Test func documentDetailSaveUpdatesDocument() {
        let document = TravelDocument(title: "Hotel")
        let viewModel = TravelDocumentDetailViewModel(document: document)
        viewModel.title = "  Hotelbuchung  "
        viewModel.documentType = "  Hotel  "
        viewModel.fileName = "  hotel.pdf  "
        viewModel.extractedText = "  Check-in 15:00  "

        viewModel.save(document: document)

        #expect(document.title == "Hotelbuchung")
        #expect(document.documentType == "Hotel")
        #expect(document.fileName == "hotel.pdf")
        #expect(document.extractedText == "Check-in 15:00")
        #expect(viewModel.errorMessage == nil)
    }

    @Test func documentDetailSaveRejectsEmptyTitle() {
        let document = TravelDocument(title: "Hotel")
        let viewModel = TravelDocumentDetailViewModel(document: document)
        viewModel.title = "   "

        viewModel.save(document: document)

        #expect(document.title == "Hotel")
        #expect(viewModel.errorMessage == "Bitte gib einen Namen fuer die Reiseunterlage ein.")
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

    @MainActor
    private func makeModelContext() throws -> ModelContext {
        let schema = Schema([
            Trip.self,
            Stop.self,
            TravelDocument.self,
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])

        return ModelContext(container)
    }
}

private struct StubLocationGeocodingService: LocationGeocoding {
    let result: Result<GeocodedCoordinate, Error>

    func coordinate(for query: String) async throws -> GeocodedCoordinate {
        try result.get()
    }
}
