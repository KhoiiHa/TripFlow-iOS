//
//  TripFlowTests.swift
//  TripFlowTests
//
//  Created by Vu Minh Khoi Ha on 05.07.26.
//

import Foundation
import MapKit
import PDFKit
import SwiftData
import Testing
import UIKit
@testable import TripFlow

struct TripFlowTests {
    private let tripService = TripService()
    private let stopService = StopService()
    private let timelineService = TimelineService()
    private let mapService = MapService()
    private let travelDocumentService = TravelDocumentService()
    private let travelDocumentParserService = TravelDocumentParserService()
    private let tripPlanningStatusService = TripPlanningStatusService()

    @Test func dateDisplayFormatterUsesGermanReadableText() {
        let scheduledDate = makeDate(year: 2026, month: 7, day: 15, hour: 14, minute: 30, calendar: testCalendar())

        #expect(DateDisplayFormatter.date(scheduledDate, calendar: testCalendar()) == "15. Juli 2026")
        #expect(DateDisplayFormatter.time(scheduledDate, calendar: testCalendar()) == "14:30")
        #expect(DateDisplayFormatter.dateTime(scheduledDate, calendar: testCalendar()) == "15. Juli 2026, 14:30")
        #expect(DateDisplayFormatter.weekdayDate(scheduledDate, calendar: testCalendar()) == "Mittwoch, 15. Juli 2026")
    }

    @Test func createTripTrimsTitle() throws {
        let trip = try tripService.createTrip(title: "  Berlin 2026  ")

        #expect(trip.title == "Berlin 2026")
    }

    @Test func createTripRejectsEmptyTitle() {
        #expect(throws: TripValidationError.emptyTitle) {
            try tripService.createTrip(title: "   ")
        }
    }

    @Test func tripListExplainsDisabledCreateTripWithoutTitle() {
        let viewModel = TripListViewModel()
        viewModel.newTripTitle = "   "

        #expect(viewModel.canCreateTrip == false)
        #expect(viewModel.createTripDisabledReason == "Name fuer den Trip fehlt.")
    }

    @Test func tripListExplainsDisabledCreateTripWithInvalidDateRange() {
        let viewModel = TripListViewModel()
        viewModel.newTripTitle = "Berlin"
        viewModel.newTripHasStartDate = true
        viewModel.newTripStartDate = Date(timeIntervalSince1970: 2)
        viewModel.newTripHasEndDate = true
        viewModel.newTripEndDate = Date(timeIntervalSince1970: 1)

        #expect(viewModel.canCreateTrip == false)
        #expect(viewModel.createTripDisabledReason == "Das Enddatum darf nicht vor dem Startdatum liegen.")
    }

    @Test func tripListCancelsCreateTripCleanly() {
        let viewModel = TripListViewModel()
        viewModel.newTripTitle = "Berlin"
        viewModel.newTripHasStartDate = true
        viewModel.newTripStartDate = Date(timeIntervalSince1970: 1)
        viewModel.newTripHasEndDate = true
        viewModel.newTripEndDate = Date(timeIntervalSince1970: 2)
        viewModel.errorMessage = "Fehler"
        viewModel.isShowingCreateTrip = true

        viewModel.cancelCreateTrip()

        #expect(viewModel.newTripTitle == "")
        #expect(viewModel.newTripHasStartDate == false)
        #expect(viewModel.newTripHasEndDate == false)
        #expect(viewModel.errorMessage == nil)
        #expect(viewModel.isShowingCreateTrip == false)
    }

    @Test @MainActor func tripListCreatesTripWithOptionalDates() throws {
        let viewModel = TripListViewModel()
        let modelContext = try makeModelContext()
        let startDate = Date(timeIntervalSince1970: 1)
        let endDate = Date(timeIntervalSince1970: 2)
        viewModel.newTripTitle = "  Berlin  "
        viewModel.newTripHasStartDate = true
        viewModel.newTripStartDate = startDate
        viewModel.newTripHasEndDate = true
        viewModel.newTripEndDate = endDate
        viewModel.isShowingCreateTrip = true

        viewModel.createTrip(in: modelContext)

        let trips = try modelContext.fetch(FetchDescriptor<Trip>())
        #expect(trips.count == 1)
        #expect(trips.first?.title == "Berlin")
        #expect(trips.first?.startDate == startDate)
        #expect(trips.first?.endDate == endDate)
        #expect(viewModel.newTripTitle == "")
        #expect(viewModel.newTripHasStartDate == false)
        #expect(viewModel.newTripHasEndDate == false)
        #expect(viewModel.isShowingCreateTrip == false)
    }

    @Test func tripPlanningStatusIsEmptyWithoutStops() throws {
        let trip = try tripService.createTrip(title: "Berlin")

        let summary = tripPlanningStatusService.summary(for: trip)

        #expect(summary.status.title == "Empty")
        #expect(summary.stopCountText == "0 Stops")
        #expect(summary.documentCountText == "0 Unterlagen")
        #expect(summary.dateRangeText == "Zeitraum offen")
    }

    @Test func tripPlanningStatusIsPlanningWithStopsOnly() throws {
        let trip = try tripService.createTrip(title: "Berlin")
        _ = try stopService.createStop(title: "Hotel", locationName: "", for: trip)

        let summary = tripPlanningStatusService.summary(for: trip)

        #expect(summary.status.title == "Planning")
        #expect(summary.stopCountText == "1 Stop")
        #expect(summary.documentCountText == "0 Unterlagen")
    }

    @Test func tripPlanningStatusIsReadyWithStopsAndDocuments() throws {
        let trip = try tripService.createTrip(title: "Berlin")
        _ = try stopService.createStop(title: "Hotel", locationName: "", for: trip)
        _ = try travelDocumentService.createDocument(title: "Hotelbuchung", for: trip)

        let summary = tripPlanningStatusService.summary(for: trip)

        #expect(summary.status.title == "Ready")
        #expect(summary.stopCountText == "1 Stop")
        #expect(summary.documentCountText == "1 Unterlage")
    }

    @Test func tripPlanningStatusFormatsDateRangeInGerman() throws {
        let trip = try tripService.createTrip(
            title: "Berlin",
            startDate: makeDate(year: 2026, month: 7, day: 15, hour: 14, minute: 30, calendar: testCalendar()),
            endDate: makeDate(year: 2026, month: 7, day: 18, hour: 9, minute: 5, calendar: testCalendar())
        )

        let summary = tripPlanningStatusService.summary(for: trip)

        #expect(summary.dateRangeText == "15. Juli 2026 - 18. Juli 2026")
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

    @Test func tripDetailExplainsDisabledSaveWithoutTitle() throws {
        let trip = try tripService.createTrip(title: "Berlin")
        let viewModel = TripDetailViewModel(trip: trip)
        viewModel.title = "   "

        #expect(viewModel.canSave == false)
        #expect(viewModel.saveDisabledReason == "Name fuer den Trip fehlt.")
    }

    @Test func tripDetailExplainsDisabledSaveWithInvalidDateRange() throws {
        let trip = try tripService.createTrip(title: "Berlin")
        let viewModel = TripDetailViewModel(trip: trip)
        viewModel.hasStartDate = true
        viewModel.hasEndDate = true
        viewModel.startDate = Date(timeIntervalSince1970: 2)
        viewModel.endDate = Date(timeIntervalSince1970: 1)

        #expect(viewModel.canSave == false)
        #expect(viewModel.saveDisabledReason == "Enddatum darf nicht vor dem Startdatum liegen.")
    }

    @Test func tripDetailSaveClearsOldErrorOnNewAttempt() throws {
        let trip = try tripService.createTrip(title: "Berlin")
        let viewModel = TripDetailViewModel(trip: trip)
        viewModel.title = "Paris"
        viewModel.errorMessage = "Alter Fehler"

        viewModel.save(trip: trip)

        #expect(trip.title == "Paris")
        #expect(viewModel.errorMessage == nil)
    }

    @Test func tripDetailProvidesPlanningSummary() throws {
        let trip = try tripService.createTrip(title: "Berlin")
        _ = try stopService.createStop(title: "Hotel", locationName: "", for: trip)
        _ = try travelDocumentService.createDocument(title: "Hotelbuchung", for: trip)
        let viewModel = TripDetailViewModel(trip: trip)

        let summary = viewModel.planningSummary(for: trip)

        #expect(summary.status.title == "Ready")
        #expect(summary.stopCountText == "1 Stop")
        #expect(summary.documentCountText == "1 Unterlage")
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

    @Test func createTravelDocumentRejectsDuplicateSourceOnlyInSameTrip() throws {
        let sourceData = Data("same ticket".utf8)
        let sourceFingerprint = "same-fingerprint"
        let berlinTrip = try tripService.createTrip(title: "Berlin")
        let parisTrip = try tripService.createTrip(title: "Paris")
        _ = try travelDocumentService.createDocument(
            title: "Boarding Pass",
            sourceData: sourceData,
            sourceFingerprint: sourceFingerprint,
            for: berlinTrip
        )

        #expect(throws: TravelDocumentValidationError.duplicateSource) {
            try travelDocumentService.createDocument(
                title: "Boarding Pass Kopie",
                sourceData: sourceData,
                sourceFingerprint: sourceFingerprint,
                for: berlinTrip
            )
        }

        let documentInOtherTrip = try travelDocumentService.createDocument(
            title: "Boarding Pass",
            sourceData: sourceData,
            sourceFingerprint: sourceFingerprint,
            for: parisTrip
        )

        #expect(documentInOtherTrip.trip === parisTrip)
    }

    @Test func createTravelDocumentRecognizesLegacySourceWithoutFingerprint() throws {
        let sourceData = Data("legacy ticket".utf8)
        let trip = try tripService.createTrip(title: "Berlin")
        _ = try travelDocumentService.createDocument(
            title: "Altes Ticket",
            sourceData: sourceData,
            for: trip
        )

        #expect(throws: TravelDocumentValidationError.duplicateSource) {
            try travelDocumentService.createDocument(
                title: "Neues Ticket",
                sourceData: sourceData,
                sourceFingerprint: "new-fingerprint",
                for: trip
            )
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

    @Test func parserExtractsFlightNumberFromBoardingText() {
        let result = travelDocumentParserService.parse("Boarding LH 2034 Gate A12 05/08/26 09:05")

        #expect(result.flightNumber == "LH2034")
        #expect(result.suggestedStopTitle == "Flug LH2034")
    }

    @Test func parserExtractsTrainNumberFromRailText() {
        let result = travelDocumentParserService.parse("Bahn ICE 100 Berlin Hbf 15.07.2026 08:30")

        #expect(result.trainNumber == "ICE100")
    }

    @Test func parserSuggestsTrainStopTitleWithTrainNumber() {
        let result = travelDocumentParserService.parse("Bahn ICE 100 Berlin Hbf 15.07.2026 08:30")

        #expect(result.suggestedStopTitle == "Bahnfahrt ICE100")
    }

    @Test func parserExtractsReservationNumberFromLabeledLine() {
        let result = travelDocumentParserService.parse(
            """
            Hotel Check-in 15.07.2026 ab 14:30 Uhr
            Reservierung: ABC12345
            """
        )

        #expect(result.reservationNumber == "ABC12345")
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

    @Test func parserSuggestsLocationNameFromRailStationLabel() {
        let result = travelDocumentParserService.parse(
            """
            Bahn ICE 100 15.07.2026 08:30
            Von: Berlin Hbf
            Nach: Hamburg Hbf
            """,
            calendar: testCalendar()
        )

        #expect(result.departureLocationName == "Berlin Hbf")
        #expect(result.arrivalLocationName == "Hamburg Hbf")
        #expect(result.suggestedLocationName == "Hamburg Hbf")
        #expect(result.departureScheduledDate == makeDate(year: 2026, month: 7, day: 15, hour: 8, minute: 30, calendar: testCalendar()))
        #expect(result.arrivalScheduledDate == nil)
        #expect(result.scheduledDate == nil)
    }

    @Test func parserRecognizesEnglishDepartureAndArrivalLabels() {
        let result = travelDocumentParserService.parse(
            """
            Flight LH 2034 05/08/26 09:05
            Departure Airport: Berlin BER
            Arrival Airport: Lisbon LIS
            """
        )

        #expect(result.departureLocationName == "Berlin BER")
        #expect(result.arrivalLocationName == "Lisbon LIS")
        #expect(result.suggestedLocationName == "Lisbon LIS")
    }

    @Test func parserFallsBackToDepartureWhenArrivalIsMissing() {
        let result = travelDocumentParserService.parse(
            """
            Bahn ICE 100 15.07.2026 08:30
            Von: Berlin Hbf
            """,
            calendar: testCalendar()
        )

        #expect(result.departureLocationName == "Berlin Hbf")
        #expect(result.arrivalLocationName == nil)
        #expect(result.suggestedLocationName == "Berlin Hbf")
        #expect(result.scheduledDate == makeDate(year: 2026, month: 7, day: 15, hour: 8, minute: 30, calendar: testCalendar()))
    }

    @Test func parserSeparatesDepartureAndArrivalSchedules() {
        let result = travelDocumentParserService.parse(
            """
            Bahn ICE 100
            Von: Berlin Hbf
            Abfahrt: 15.07.2026 08:30
            Nach: Hamburg Hbf
            Ankunft: 15.07.2026 10:45
            """,
            calendar: testCalendar()
        )

        let departure = makeDate(year: 2026, month: 7, day: 15, hour: 8, minute: 30, calendar: testCalendar())
        let arrival = makeDate(year: 2026, month: 7, day: 15, hour: 10, minute: 45, calendar: testCalendar())

        #expect(result.departureScheduledDate == departure)
        #expect(result.arrivalScheduledDate == arrival)
        #expect(result.scheduledDate == arrival)
        #expect(result.date == TravelDocumentParsedDate(day: 15, month: 7, year: 2026))
        #expect(result.time == TravelDocumentParsedTime(hour: 10, minute: 45))
    }

    @Test func parserUsesDocumentDateForLabeledArrivalTime() {
        let result = travelDocumentParserService.parse(
            """
            Flug LH 2034 am 05.08.2026
            From: Berlin BER
            Departure: 09:05
            To: Lisbon LIS
            Arrival: 11:40
            """,
            calendar: testCalendar()
        )

        #expect(result.departureScheduledDate == makeDate(year: 2026, month: 8, day: 5, hour: 9, minute: 5, calendar: testCalendar()))
        #expect(result.arrivalScheduledDate == makeDate(year: 2026, month: 8, day: 5, hour: 11, minute: 40, calendar: testCalendar()))
        #expect(result.scheduledDate == result.arrivalScheduledDate)
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

        #expect(viewModel.documentSubtitle(for: document) == "Booking - hotel.pdf - OCR offen")
    }

    @Test func tripDetailDocumentSubtitleUsesParsedReferenceMetadata() throws {
        let trip = try tripService.createTrip(title: "Berlin")
        let document = try travelDocumentService.createDocument(
            title: "Boarding Pass",
            documentType: "Flug",
            extractedText: """
            Boarding LH 2034 Gate A12 05/08/26 09:05
            Buchungsnummer: XYZ789
            """,
            for: trip
        )
        let viewModel = TripDetailViewModel(trip: trip)

        #expect(viewModel.documentSubtitle(for: document) == "Flug - Flug LH2034 - Ref XYZ789 - 05.08.2026 09:05 - OCR vorhanden")
    }

    @Test func tripDetailDocumentSubtitleShowsOCRStatusForExtractedText() throws {
        let trip = try tripService.createTrip(title: "Berlin")
        let document = try travelDocumentService.createDocument(
            title: "Hotel",
            extractedText: "  Check-in 15.07.2026  ",
            for: trip
        )
        let viewModel = TripDetailViewModel(trip: trip)

        #expect(viewModel.documentSubtitle(for: document) == "15.07.2026 - OCR vorhanden")
    }

    @Test func tripDetailDocumentSubtitleShowsParsedDateAndTime() throws {
        let trip = try tripService.createTrip(title: "Berlin")
        let document = try travelDocumentService.createDocument(
            title: "Hotel",
            extractedText: "Check-in 15.07.2026 ab 14:30 Uhr",
            for: trip
        )
        let viewModel = TripDetailViewModel(trip: trip)

        #expect(viewModel.documentSubtitle(for: document) == "15.07.2026 14:30 - OCR vorhanden")
    }

    @Test func tripDetailDocumentSubtitleShowsParsedLocationName() throws {
        let trip = try tripService.createTrip(title: "Berlin")
        let document = try travelDocumentService.createDocument(
            title: "Hotel",
            extractedText: """
            Check-in 15.07.2026 ab 14:30 Uhr
            Adresse: Alexanderplatz 1, Berlin
            """,
            for: trip
        )
        let viewModel = TripDetailViewModel(trip: trip)

        #expect(viewModel.documentSubtitle(for: document) == "Ort Alexanderplatz 1, Berlin - 15.07.2026 14:30 - OCR vorhanden")
    }

    @Test func tripDetailDocumentSubtitleShowsParsedTrainNumber() throws {
        let trip = try tripService.createTrip(title: "Berlin")
        let document = try travelDocumentService.createDocument(
            title: "Bahnticket",
            documentType: "Bahn",
            extractedText: "Bahn ICE 100 Berlin Hbf 15.07.2026 08:30",
            for: trip
        )
        let viewModel = TripDetailViewModel(trip: trip)

        #expect(viewModel.documentSubtitle(for: document) == "Bahn - Zug ICE100 - 15.07.2026 08:30 - OCR vorhanden")
    }

    @Test func tripDetailDocumentMetadataBadgesHighlightTypeDateAndOCRStatus() throws {
        let trip = try tripService.createTrip(title: "Berlin")
        let document = try travelDocumentService.createDocument(
            title: "Hotel",
            documentType: "Hotel",
            extractedText: "Check-in 15.07.2026 ab 14:30 Uhr",
            for: trip
        )
        let viewModel = TripDetailViewModel(trip: trip)

        let badges = viewModel.documentMetadataBadges(for: document)

        #expect(badges == [
            DocumentMetadataBadge(title: "Hotel", systemImage: "doc.text", isHighlighted: false),
            DocumentMetadataBadge(title: "15.07.2026 14:30", systemImage: "calendar", isHighlighted: true),
            DocumentMetadataBadge(title: "OCR vorhanden", systemImage: "text.viewfinder", isHighlighted: true)
        ])
    }

    @Test func tripDetailDocumentMetadataBadgesShowOpenOCRWithoutExtractedText() throws {
        let trip = try tripService.createTrip(title: "Berlin")
        let document = try travelDocumentService.createDocument(
            title: "Hotel",
            fileName: "hotel.pdf",
            for: trip
        )
        let viewModel = TripDetailViewModel(trip: trip)

        let badges = viewModel.documentMetadataBadges(for: document)

        #expect(badges == [
            DocumentMetadataBadge(title: "OCR offen", systemImage: "doc.badge.ellipsis", isHighlighted: false)
        ])
    }

    @Test func tripDetailDocumentListDetailTextShowsSupportingMetadataOnly() throws {
        let trip = try tripService.createTrip(title: "Berlin")
        let document = try travelDocumentService.createDocument(
            title: "Boarding Pass",
            documentType: "Flug",
            fileName: "boarding.pdf",
            extractedText: """
            Boarding LH 2034 Gate A12 05/08/26 09:05
            Buchungsnummer: XYZ789
            """,
            for: trip
        )
        let viewModel = TripDetailViewModel(trip: trip)

        #expect(viewModel.documentListDetailText(for: document) == "boarding.pdf - Flug LH2034 - Ref XYZ789")
    }

    @Test func tripDetailPrefillsNewStopFromDocumentSchedule() throws {
        let trip = try tripService.createTrip(title: "Berlin")
        let document = try travelDocumentService.createDocument(
            title: "Importierte Unterlage",
            documentType: "Hotel",
            extractedText: """
            Check-in 15.07.2026 ab 14:30 Uhr
            Adresse: Alexanderplatz 1, Berlin
            Reservierung: ABC12345
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
        #expect(viewModel.stopSuggestionTextExcerpt == "Check-in 15.07.2026 ab 14:30 Uhr\nAdresse: Alexanderplatz 1, Berlin\nReservierung: ABC12345")
        #expect(viewModel.stopSuggestionReservationNumber == "ABC12345")
    }

    @Test func tripDetailPrefillsDocumentFlightNumberForStopReview() throws {
        let trip = try tripService.createTrip(title: "Berlin")
        let document = try travelDocumentService.createDocument(
            title: "Boarding Pass",
            extractedText: "Boarding LH 2034 Gate A12 05/08/26 09:05",
            for: trip
        )
        let viewModel = TripDetailViewModel(trip: trip)

        viewModel.showCreateStop(from: document, calendar: testCalendar())

        #expect(viewModel.newStopTitle == "Flug LH2034")
        #expect(viewModel.stopSuggestionFlightNumber == "LH2034")
    }

    @Test func tripDetailPrefillsDocumentTrainNumberForStopReview() throws {
        let trip = try tripService.createTrip(title: "Berlin")
        let document = try travelDocumentService.createDocument(
            title: "Bahnticket",
            extractedText: """
            Bahn ICE 100 15.07.2026 08:30
            Von: Berlin Hbf
            Nach: Hamburg Hbf
            """,
            for: trip
        )
        let viewModel = TripDetailViewModel(trip: trip)

        viewModel.showCreateStop(from: document, calendar: testCalendar())

        #expect(viewModel.newStopTitle == "Bahnfahrt ICE100")
        #expect(viewModel.newStopLocationName == "Hamburg Hbf")
        #expect(viewModel.stopSuggestionTrainNumber == "ICE100")
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

        #expect(viewModel.canCreateStop == false)
        #expect(viewModel.createStopDisabledReason == "Datum und Uhrzeit fuer den vorgeschlagenen Stop fehlen.")

        viewModel.createStop(for: trip, in: modelContext)

        #expect(trip.stops.isEmpty)
        #expect(viewModel.stopErrorMessage == "Bitte waehle ein Datum und eine Uhrzeit fuer den vorgeschlagenen Stop aus.")
        #expect(viewModel.isShowingCreateStop)
    }

    @Test @MainActor func tripDetailRejectsDocumentStopSuggestionWithoutTitle() throws {
        let trip = try tripService.createTrip(title: "Berlin")
        let document = try travelDocumentService.createDocument(
            title: "Hotel Check-in",
            extractedText: "Check-in 15.07.2026 ab 14:30 Uhr",
            for: trip
        )
        let viewModel = TripDetailViewModel(trip: trip)
        let modelContext = try makeModelContext()
        viewModel.showCreateStop(from: document, calendar: testCalendar())
        viewModel.newStopTitle = "   "

        viewModel.createStop(for: trip, in: modelContext)

        #expect(trip.stops.isEmpty)
        #expect(viewModel.stopErrorMessage == "Bitte gib einen Namen fuer den vorgeschlagenen Stop ein.")
        #expect(viewModel.isShowingCreateStop)
    }

    @Test func tripDetailCancelsDocumentStopSuggestionCleanly() throws {
        let trip = try tripService.createTrip(title: "Berlin")
        let document = try travelDocumentService.createDocument(
            title: "Hotel Check-in",
            documentType: "Hotel",
            extractedText: "Check-in 15.07.2026 ab 14:30 Uhr Reservierung: ABC12345",
            for: trip
        )
        let viewModel = TripDetailViewModel(trip: trip)
        viewModel.showCreateStop(from: document, calendar: testCalendar())
        viewModel.stopErrorMessage = "Fehler"

        viewModel.cancelCreateStop()

        #expect(viewModel.isShowingCreateStop == false)
        #expect(viewModel.isReviewingDocumentStopSuggestion == false)
        #expect(viewModel.newStopTitle == "")
        #expect(viewModel.newStopScheduledDate == nil)
        #expect(viewModel.stopSuggestionDocumentType == "")
        #expect(viewModel.stopSuggestionReservationNumber == "")
        #expect(viewModel.stopErrorMessage == nil)
    }

    @Test @MainActor func tripDetailShowsSuccessAfterCreatingStopFromDocumentSuggestion() throws {
        let trip = try tripService.createTrip(title: "Berlin")
        let document = try travelDocumentService.createDocument(
            title: "Hotel Check-in",
            extractedText: "Check-in 15.07.2026 ab 14:30 Uhr",
            for: trip
        )
        let viewModel = TripDetailViewModel(trip: trip)
        let modelContext = try makeModelContext()
        viewModel.showCreateStop(from: document, calendar: testCalendar())

        viewModel.createStop(for: trip, in: modelContext)

        #expect(viewModel.stopSuccessMessage == "Stop \"Hotel Check-in\" wurde aus der Reiseunterlage erstellt.")
        #expect(viewModel.stopErrorMessage == nil)
        #expect(viewModel.isShowingCreateStop == false)
    }

    @Test @MainActor func tripDetailClearsStopSuccessWhenCreateStopStartsAgain() throws {
        let trip = try tripService.createTrip(title: "Berlin")
        let viewModel = TripDetailViewModel(trip: trip)
        let modelContext = try makeModelContext()
        viewModel.showCreateStop()
        viewModel.newStopTitle = "Hotel"

        viewModel.createStop(for: trip, in: modelContext)
        viewModel.showCreateStop()

        #expect(viewModel.stopSuccessMessage == nil)
    }

    @Test @MainActor func tripDetailCreateStopClearsOldErrorOnNewAttempt() throws {
        let trip = try tripService.createTrip(title: "Berlin")
        let viewModel = TripDetailViewModel(trip: trip)
        let modelContext = try makeModelContext()
        viewModel.showCreateStop()
        viewModel.newStopTitle = "Hotel"
        viewModel.stopErrorMessage = "Alter Fehler"

        viewModel.createStop(for: trip, in: modelContext)

        #expect(trip.stops.count == 1)
        #expect(viewModel.stopErrorMessage == nil)
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

    @Test func tripDetailExplainsDocumentTextUsage() throws {
        let trip = try tripService.createTrip(title: "Berlin")
        let viewModel = TripDetailViewModel(trip: trip)

        #expect(
            viewModel.newDocumentExtractedTextHint
                == "Importierter oder eingefuegter OCR-Text wird nach dem Speichern fuer erkannte Reisedaten und Stop-Vorschlaege genutzt."
        )
    }

    @Test func tripDetailExplainsDisabledCreateDocumentWithoutTitle() throws {
        let trip = try tripService.createTrip(title: "Berlin")
        let viewModel = TripDetailViewModel(trip: trip)
        viewModel.newDocumentTitle = "   "

        #expect(viewModel.canCreateDocument == false)
        #expect(viewModel.createDocumentDisabledReason == "Name fuer die Reiseunterlage fehlt.")
    }

    @Test func tripDetailAppliesDocumentTypeSuggestion() throws {
        let trip = try tripService.createTrip(title: "Berlin")
        let viewModel = TripDetailViewModel(trip: trip)

        #expect(viewModel.newDocumentTypeSuggestions.contains("Hotel"))

        viewModel.applyNewDocumentTypeSuggestion("Hotel")

        #expect(viewModel.newDocumentType == "Hotel")
    }

    @Test @MainActor func tripDetailImportsRecognizedTextForReviewWithoutSavingDocument() async throws {
        let trip = try tripService.createTrip(title: "Berlin")
        let imageURL = URL(fileURLWithPath: "/tmp/boarding-pass.png")
        let viewModel = TripDetailViewModel(
            trip: trip,
            travelDocumentOCRService: TravelDocumentOCRServiceStub(
                recognizedText: "Flug LH 2034 am 05.08.2026 um 09:05"
            ),
            travelDocumentSourceService: TravelDocumentSourceServiceStub()
        )

        await viewModel.importDocumentFile(from: .success([imageURL]))

        #expect(viewModel.newDocumentTitle == "boarding-pass")
        #expect(viewModel.newDocumentFileName == "boarding-pass.png")
        #expect(viewModel.newDocumentExtractedText == "Flug LH 2034 am 05.08.2026 um 09:05")
        #expect(viewModel.documentImportSuccessMessage == "Text wurde erkannt und kann vor dem Speichern geprueft werden.")
        #expect(viewModel.documentErrorMessage == nil)
        #expect(viewModel.isImportingDocument == false)
        #expect(trip.documents.isEmpty)
    }

    @Test @MainActor func tripDetailKeepsExistingDraftWhenOCRFindsNoText() async throws {
        let trip = try tripService.createTrip(title: "Berlin")
        let viewModel = TripDetailViewModel(
            trip: trip,
            travelDocumentOCRService: TravelDocumentOCRServiceStub(error: .noRecognizedText)
        )
        viewModel.newDocumentTitle = "Bestehender Entwurf"
        viewModel.newDocumentExtractedText = "Manuell erfasster Text"

        await viewModel.importDocumentFile(
            from: .success([URL(fileURLWithPath: "/tmp/leer.png")])
        )

        #expect(viewModel.newDocumentTitle == "Bestehender Entwurf")
        #expect(viewModel.newDocumentFileName.isEmpty)
        #expect(viewModel.newDocumentExtractedText == "Manuell erfasster Text")
        #expect(viewModel.documentErrorMessage == "In der ausgewaehlten Datei wurde kein Text erkannt.")
        #expect(viewModel.documentImportSuccessMessage == nil)
        #expect(viewModel.isImportingDocument == false)
        #expect(trip.documents.isEmpty)
    }

    @Test @MainActor func tripDetailImportsMultiPageScanForReviewWithoutSavingDocument() async throws {
        let trip = try tripService.createTrip(title: "Berlin")
        let viewModel = TripDetailViewModel(
            trip: trip,
            travelDocumentOCRService: TravelDocumentOCRServiceStub(
                recognizedText: "Flug LH 2034\n\nGate A12"
            ),
            travelDocumentSourceService: TravelDocumentSourceServiceStub()
        )
        viewModel.isShowingDocumentScanner = true

        await viewModel.importScannedDocumentPages([Data([1]), Data([2])])

        #expect(viewModel.newDocumentTitle == "Dokumentenscan")
        #expect(viewModel.newDocumentFileName == "Dokumentenscan.pdf")
        #expect(viewModel.newDocumentExtractedText == "Flug LH 2034\n\nGate A12")
        #expect(viewModel.documentImportSuccessMessage == "2 gescannte Seiten wurden erkannt und koennen geprueft werden.")
        #expect(viewModel.documentErrorMessage == nil)
        #expect(viewModel.isShowingDocumentScanner == false)
        #expect(viewModel.isImportingDocument == false)
        #expect(trip.documents.isEmpty)
    }

    @Test @MainActor func tripDetailKeepsExistingDraftWhenScannedTextCannotBeRead() async throws {
        let trip = try tripService.createTrip(title: "Berlin")
        let viewModel = TripDetailViewModel(
            trip: trip,
            travelDocumentOCRService: TravelDocumentOCRServiceStub(error: .unreadableImage)
        )
        viewModel.newDocumentTitle = "Bestehender Entwurf"
        viewModel.newDocumentFileName = "ticket.png"
        viewModel.newDocumentExtractedText = "Manueller Text"

        await viewModel.importScannedDocumentPages([Data([1])])

        #expect(viewModel.newDocumentTitle == "Bestehender Entwurf")
        #expect(viewModel.newDocumentFileName == "ticket.png")
        #expect(viewModel.newDocumentExtractedText == "Manueller Text")
        #expect(viewModel.documentErrorMessage == "Mindestens eine gescannte Seite konnte nicht gelesen werden.")
        #expect(viewModel.documentImportSuccessMessage == nil)
        #expect(trip.documents.isEmpty)
    }

    @Test func tripDetailCancelsDocumentScannerWithoutChangingDraft() throws {
        let trip = try tripService.createTrip(title: "Berlin")
        let viewModel = TripDetailViewModel(trip: trip)
        viewModel.newDocumentExtractedText = "Bestehender Text"

        viewModel.showDocumentScanner()
        viewModel.cancelDocumentScanner()

        #expect(viewModel.isShowingDocumentScanner == false)
        #expect(viewModel.newDocumentExtractedText == "Bestehender Text")
        #expect(viewModel.documentErrorMessage == nil)
    }

    @Test func tripDetailReportsDocumentScannerFailureWithoutChangingDraft() throws {
        let trip = try tripService.createTrip(title: "Berlin")
        let viewModel = TripDetailViewModel(trip: trip)
        viewModel.newDocumentExtractedText = "Bestehender Text"
        viewModel.isShowingDocumentScanner = true

        viewModel.failDocumentScanner()

        #expect(viewModel.isShowingDocumentScanner == false)
        #expect(viewModel.newDocumentExtractedText == "Bestehender Text")
        #expect(viewModel.documentErrorMessage == "Das Dokument konnte nicht gescannt werden.")
    }

    @Test @MainActor func tripDetailImportsPDFForReviewWithoutSavingDocument() async throws {
        let trip = try tripService.createTrip(title: "Berlin")
        let pdfURL = URL(fileURLWithPath: "/tmp/hotel-booking.pdf")
        let viewModel = TripDetailViewModel(
            trip: trip,
            travelDocumentOCRService: TravelDocumentOCRServiceStub(
                recognizedText: "Check-in 15.08.2026 um 15:00"
            ),
            travelDocumentSourceService: TravelDocumentSourceServiceStub()
        )

        await viewModel.importDocumentFile(from: .success([pdfURL]))

        #expect(viewModel.newDocumentTitle == "hotel-booking")
        #expect(viewModel.newDocumentFileName == "hotel-booking.pdf")
        #expect(viewModel.newDocumentExtractedText == "Check-in 15.08.2026 um 15:00")
        #expect(viewModel.documentErrorMessage == nil)
        #expect(viewModel.isImportingDocument == false)
        #expect(trip.documents.isEmpty)
    }

    @Test @MainActor func documentSourceCreatesMultiPagePDFFromScanImages() throws {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 120, height: 180))
        let firstPage = renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 120, height: 180))
        }
        let secondPage = renderer.image { context in
            UIColor.lightGray.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 120, height: 180))
        }
        let pages = try [firstPage, secondPage].map { image in
            try #require(image.jpegData(compressionQuality: 0.9))
        }

        let pdfData = try TravelDocumentSourceService().pdfData(fromScannedPages: pages)
        let document = try #require(PDFDocument(data: pdfData))

        #expect(document.pageCount == 2)
    }

    @Test @MainActor func documentSourceReadsImportedFileData() throws {
        let sourceURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("tripflow-source-\(UUID().uuidString).pdf")
        let expectedData = Data("original document".utf8)
        try expectedData.write(to: sourceURL)
        defer { try? FileManager.default.removeItem(at: sourceURL) }

        let sourceData = try TravelDocumentSourceService().data(from: sourceURL)

        #expect(sourceData == expectedData)
    }

    @Test @MainActor func documentSourceRejectsImportedFileAboveSizeLimit() throws {
        let sourceURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("tripflow-large-source-\(UUID().uuidString).pdf")
        try Data(repeating: 1, count: 5).write(to: sourceURL)
        defer { try? FileManager.default.removeItem(at: sourceURL) }
        let service = TravelDocumentSourceService(maximumSourceByteCount: 4)

        #expect(throws: TravelDocumentSourceError.sourceTooLarge(maximumByteCount: 4)) {
            try service.validateDocument(at: sourceURL)
        }
    }

    @Test @MainActor func documentSourceFingerprintIsStableAndContentBased() {
        let service = TravelDocumentSourceService()

        let firstFingerprint = service.fingerprint(for: Data("ticket".utf8))
        let repeatedFingerprint = service.fingerprint(for: Data("ticket".utf8))
        let differentFingerprint = service.fingerprint(for: Data("other ticket".utf8))

        #expect(firstFingerprint.count == 64)
        #expect(firstFingerprint == repeatedFingerprint)
        #expect(firstFingerprint != differentFingerprint)
    }

    @Test @MainActor func documentSourceRejectsScanAbovePageAndSizeLimits() {
        let service = TravelDocumentSourceService(
            maximumSourceByteCount: 5,
            maximumScanPageCount: 2
        )

        #expect(throws: TravelDocumentSourceError.tooManyScanPages(maximumPageCount: 2)) {
            try service.validateScannedPages([Data([1]), Data([2]), Data([3])])
        }
        #expect(throws: TravelDocumentSourceError.sourceTooLarge(maximumByteCount: 5)) {
            try service.validateScannedPages([Data(repeating: 1, count: 3), Data(repeating: 2, count: 3)])
        }
    }

    @Test @MainActor func documentSourceCreatesAndRemovesTemporaryPreviewFile() throws {
        let sourceData = Data("preview document".utf8)
        let service = TravelDocumentSourceService()

        let previewURL = try service.temporaryPreviewURL(
            for: sourceData,
            fileName: "ticket.pdf"
        )

        #expect(previewURL.pathExtension == "pdf")
        #expect(try Data(contentsOf: previewURL) == sourceData)

        service.removeTemporaryPreview(at: previewURL)

        #expect(FileManager.default.fileExists(atPath: previewURL.path) == false)
    }

    @Test @MainActor func documentSourceCreatesNamedExportAndRemovesTemporaryDirectory() throws {
        let sourceData = Data("shared document".utf8)
        let service = TravelDocumentSourceService()

        let exportURL = try service.temporaryExportURL(
            for: sourceData,
            fileName: "/imports/boarding-pass.pdf"
        )

        #expect(exportURL.lastPathComponent == "boarding-pass.pdf")
        #expect(try Data(contentsOf: exportURL) == sourceData)

        let exportDirectory = exportURL.deletingLastPathComponent()
        service.removeTemporaryExport(at: exportURL)

        #expect(FileManager.default.fileExists(atPath: exportDirectory.path) == false)
    }

    @Test @MainActor func tripDetailStoresImportedSourceOnlyAfterDocumentConfirmation() async throws {
        let sourceData = Data("original document".utf8)
        let trip = try tripService.createTrip(title: "Berlin")
        let modelContext = try makeModelContext()
        modelContext.insert(trip)
        let viewModel = TripDetailViewModel(
            trip: trip,
            travelDocumentOCRService: TravelDocumentOCRServiceStub(
                recognizedText: "Flug LH 2034 am 05.08.2026 um 09:05"
            ),
            travelDocumentSourceService: TravelDocumentSourceServiceStub(
                sourceData: sourceData
            )
        )

        await viewModel.importDocumentFile(
            from: .success([URL(fileURLWithPath: "/tmp/boarding-pass.pdf")])
        )

        #expect(trip.documents.isEmpty)

        viewModel.createDocument(for: trip, in: modelContext)
        try modelContext.save()

        let documents = try modelContext.fetch(FetchDescriptor<TravelDocument>())
        #expect(documents.count == 1)
        #expect(documents.first?.sourceData == sourceData)
        #expect(documents.first?.sourceFingerprint == "source-fingerprint")
        #expect(documents.first?.fileName == "boarding-pass.pdf")
    }

    @Test @MainActor func tripDetailDiscardsImportedSourceWhenDocumentDraftIsCancelled() async throws {
        let trip = try tripService.createTrip(title: "Berlin")
        let modelContext = try makeModelContext()
        let viewModel = TripDetailViewModel(
            trip: trip,
            travelDocumentOCRService: TravelDocumentOCRServiceStub(
                recognizedText: "Check-in 15.08.2026 um 15:00"
            ),
            travelDocumentSourceService: TravelDocumentSourceServiceStub(
                sourceData: Data("temporary source".utf8)
            )
        )

        await viewModel.importDocumentFile(
            from: .success([URL(fileURLWithPath: "/tmp/hotel.pdf")])
        )
        viewModel.cancelCreateDocument()

        viewModel.newDocumentTitle = "Manuelle Notiz"
        viewModel.createDocument(for: trip, in: modelContext)

        #expect(trip.documents.count == 1)
        #expect(trip.documents.first?.sourceData == nil)
    }

    @Test @MainActor func tripDetailRejectsOversizedImportWithoutChangingDraft() async throws {
        let maximumByteCount = TravelDocumentSourceService.defaultMaximumSourceByteCount
        let trip = try tripService.createTrip(title: "Berlin")
        let viewModel = TripDetailViewModel(
            trip: trip,
            travelDocumentOCRService: TravelDocumentOCRServiceStub(
                recognizedText: "Neuer erkannter Text"
            ),
            travelDocumentSourceService: TravelDocumentSourceServiceStub(
                validationError: .sourceTooLarge(maximumByteCount: maximumByteCount)
            )
        )
        viewModel.newDocumentTitle = "Bestehender Entwurf"
        viewModel.newDocumentFileName = "bestehend.pdf"
        viewModel.newDocumentExtractedText = "Bestehender Text"

        await viewModel.importDocumentFile(
            from: .success([URL(fileURLWithPath: "/tmp/zu-gross.pdf")])
        )

        #expect(viewModel.newDocumentTitle == "Bestehender Entwurf")
        #expect(viewModel.newDocumentFileName == "bestehend.pdf")
        #expect(viewModel.newDocumentExtractedText == "Bestehender Text")
        #expect(viewModel.documentErrorMessage == "Die ausgewaehlte Datei darf hoechstens 25 MB gross sein.")
        #expect(viewModel.documentImportSuccessMessage == nil)
        #expect(viewModel.isImportingDocument == false)
        #expect(trip.documents.isEmpty)
    }

    @Test @MainActor func tripDetailRejectsTooManyScanPagesWithoutChangingDraft() async throws {
        let maximumPageCount = TravelDocumentSourceService.defaultMaximumScanPageCount
        let trip = try tripService.createTrip(title: "Berlin")
        let viewModel = TripDetailViewModel(
            trip: trip,
            travelDocumentOCRService: TravelDocumentOCRServiceStub(
                recognizedText: "Neuer erkannter Text"
            ),
            travelDocumentSourceService: TravelDocumentSourceServiceStub(
                validationError: .tooManyScanPages(maximumPageCount: maximumPageCount)
            )
        )
        viewModel.newDocumentTitle = "Bestehender Entwurf"
        viewModel.newDocumentExtractedText = "Bestehender Text"

        await viewModel.importScannedDocumentPages([Data([1])])

        #expect(viewModel.newDocumentTitle == "Bestehender Entwurf")
        #expect(viewModel.newDocumentExtractedText == "Bestehender Text")
        #expect(viewModel.documentErrorMessage == "Ein Scan darf hoechstens 20 Seiten enthalten.")
        #expect(viewModel.documentImportSuccessMessage == nil)
        #expect(viewModel.isImportingDocument == false)
        #expect(trip.documents.isEmpty)
    }

    @Test @MainActor func tripDetailRejectsDuplicateImportedSourceWithoutClosingDraft() async throws {
        let sourceData = Data("same ticket".utf8)
        let sourceFingerprint = "same-fingerprint"
        let trip = try tripService.createTrip(title: "Berlin")
        _ = try travelDocumentService.createDocument(
            title: "Boarding Pass",
            sourceData: sourceData,
            sourceFingerprint: sourceFingerprint,
            for: trip
        )
        let modelContext = try makeModelContext()
        let viewModel = TripDetailViewModel(
            trip: trip,
            travelDocumentOCRService: TravelDocumentOCRServiceStub(
                recognizedText: "Flug LH 2034 am 05.08.2026 um 09:05"
            ),
            travelDocumentSourceService: TravelDocumentSourceServiceStub(
                sourceData: sourceData,
                sourceFingerprint: sourceFingerprint
            )
        )
        viewModel.isShowingCreateDocument = true

        await viewModel.importDocumentFile(
            from: .success([URL(fileURLWithPath: "/tmp/boarding-pass-copy.pdf")])
        )
        viewModel.createDocument(for: trip, in: modelContext)

        #expect(trip.documents.count == 1)
        #expect(viewModel.documentErrorMessage == "Diese Originaldatei ist in diesem Trip bereits gespeichert.")
        #expect(viewModel.isShowingCreateDocument)
        #expect(viewModel.newDocumentTitle == "boarding-pass-copy")
        #expect(viewModel.newDocumentExtractedText.isEmpty == false)
    }

    @Test @MainActor func documentOCRReadsEmbeddedTextFromPDF() async throws {
        let pdfURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("tripflow-\(UUID().uuidString).pdf")
        defer { try? FileManager.default.removeItem(at: pdfURL) }

        let renderer = UIGraphicsPDFRenderer(
            bounds: CGRect(x: 0, y: 0, width: 600, height: 800)
        )
        let pdfData = renderer.pdfData { context in
            context.beginPage()
            ("Flug LH 2034 am 05.08.2026 um 09:05" as NSString).draw(
                at: CGPoint(x: 40, y: 40),
                withAttributes: [.font: UIFont.systemFont(ofSize: 18)]
            )
        }
        try pdfData.write(to: pdfURL)

        let recognizedText = try await TravelDocumentOCRService()
            .recognizeText(inDocumentAt: pdfURL)

        #expect(recognizedText.contains("Flug LH 2034"))
        #expect(recognizedText.contains("05.08.2026"))
    }

    @Test func tripDetailBuildsReviewForRecognizedDocumentDraft() throws {
        let trip = try tripService.createTrip(title: "Berlin")
        let viewModel = TripDetailViewModel(trip: trip)
        viewModel.newDocumentExtractedText = """
        Flug LH 2034 am 05.08.2026 um 09:05
        Adresse: Flughafen Berlin Brandenburg
        Buchungsnummer: XYZ789
        """

        let items = viewModel.newDocumentRecognitionSummaryItems(
            calendar: testCalendar()
        )

        #expect(viewModel.hasNewDocumentExtractedText)
        #expect(items.map(\.id) == ["stopTitle", "schedule", "location", "reference"])
        #expect(items.first(where: { $0.id == "stopTitle" })?.value == "Flug LH2034")
        #expect(items.first(where: { $0.id == "schedule" })?.value == "5. August 2026, 09:05")
        #expect(items.first(where: { $0.id == "location" })?.value == "Flughafen Berlin Brandenburg")
        #expect(items.first(where: { $0.id == "reference" })?.value == "Flug LH2034 - Ref XYZ789")
        #expect(trip.documents.isEmpty)
    }

    @Test func tripDetailReportsUnstructuredDocumentDraftWithoutSummary() throws {
        let trip = try tripService.createTrip(title: "Berlin")
        let viewModel = TripDetailViewModel(trip: trip)
        viewModel.newDocumentExtractedText = "Vielen Dank fuer Ihre Buchung."

        #expect(viewModel.hasNewDocumentExtractedText)
        #expect(viewModel.newDocumentRecognitionSummaryItems().isEmpty)
        #expect(trip.documents.isEmpty)
    }

    @Test func tripDetailBuildsDepartureAndArrivalReviewForRouteDocument() throws {
        let trip = try tripService.createTrip(title: "Europa")
        let viewModel = TripDetailViewModel(trip: trip)
        viewModel.newDocumentExtractedText = """
        Bahn ICE 100
        Von: Berlin Hbf
        Abfahrt: 15.07.2026 08:30
        Nach: Hamburg Hbf
        Ankunft: 15.07.2026 10:45
        """

        let items = viewModel.newDocumentRecognitionSummaryItems(calendar: testCalendar())

        #expect(items.map(\.id) == ["stopTitle", "departure", "departureSchedule", "arrival", "arrivalSchedule", "reference"])
        #expect(items.first { $0.id == "departure" }?.value == "Berlin Hbf")
        #expect(items.first { $0.id == "departureSchedule" }?.value == "15. Juli 2026, 08:30")
        #expect(items.first { $0.id == "arrival" }?.value == "Hamburg Hbf")
        #expect(items.first { $0.id == "arrivalSchedule" }?.value == "15. Juli 2026, 10:45")
    }

    @Test func tripDetailOffersStopReviewOnlyForCompleteScheduleInDraft() throws {
        let trip = try tripService.createTrip(title: "Berlin")
        let viewModel = TripDetailViewModel(trip: trip)

        viewModel.newDocumentExtractedText = "Flug LH 2034 am 05.08.2026"
        #expect(viewModel.canReviewNewDocumentStopSuggestion == false)

        viewModel.newDocumentExtractedText += " um 09:05"
        #expect(viewModel.canReviewNewDocumentStopSuggestion)
    }

    @Test @MainActor func tripDetailCreatesStopOnlyAfterDraftReviewConfirmation() throws {
        let trip = try tripService.createTrip(title: "Berlin")
        let viewModel = TripDetailViewModel(trip: trip)
        let modelContext = try makeModelContext()
        viewModel.newDocumentTitle = "Boarding Pass"
        viewModel.newDocumentType = "Flug"
        viewModel.newDocumentExtractedText = """
        Flug LH 2034 am 05.08.2026 um 09:05
        Flughafen: Berlin Brandenburg
        """
        viewModel.isShowingCreateDocument = true

        viewModel.createDocument(
            for: trip,
            in: modelContext,
            reviewStopSuggestion: true
        )

        #expect(trip.documents.count == 1)
        #expect(trip.stops.isEmpty)
        #expect(viewModel.isShowingCreateDocument == false)
        #expect(viewModel.isShowingCreateStop == false)

        viewModel.showPendingDocumentStopSuggestion()

        #expect(viewModel.isShowingCreateStop)
        #expect(viewModel.isReviewingDocumentStopSuggestion)
        #expect(viewModel.newStopTitle == "Flug LH2034")
        #expect(viewModel.newStopLocationName == "Berlin Brandenburg")
        #expect(trip.stops.isEmpty)

        viewModel.createStop(for: trip, in: modelContext)

        #expect(trip.stops.count == 1)
        #expect(trip.stops.first?.title == "Flug LH2034")
        #expect(viewModel.isShowingCreateStop == false)
    }

    @Test @MainActor func tripDetailCreateDocumentClearsOldErrorOnNewAttempt() throws {
        let trip = try tripService.createTrip(title: "Berlin")
        let viewModel = TripDetailViewModel(trip: trip)
        let modelContext = try makeModelContext()
        viewModel.newDocumentTitle = "Hotelbuchung"
        viewModel.documentErrorMessage = "Alter Fehler"
        viewModel.isShowingCreateDocument = true

        viewModel.createDocument(for: trip, in: modelContext)

        #expect(trip.documents.count == 1)
        #expect(viewModel.documentErrorMessage == nil)
    }

    @Test func tripDetailCancelsCreateDocumentCleanly() throws {
        let trip = try tripService.createTrip(title: "Berlin")
        let viewModel = TripDetailViewModel(trip: trip)
        viewModel.newDocumentTitle = "Hotelbuchung"
        viewModel.newDocumentType = "Hotel"
        viewModel.newDocumentFileName = "hotel.pdf"
        viewModel.newDocumentExtractedText = "Check-in 15.07.2026"
        viewModel.documentErrorMessage = "Fehler"
        viewModel.documentImportSuccessMessage = "Importiert"
        viewModel.isShowingDocumentImporter = true
        viewModel.isShowingDocumentScanner = true
        viewModel.isImportingDocument = true
        viewModel.isShowingCreateDocument = true

        viewModel.cancelCreateDocument()

        #expect(viewModel.newDocumentTitle == "")
        #expect(viewModel.newDocumentType == "")
        #expect(viewModel.newDocumentFileName == "")
        #expect(viewModel.newDocumentExtractedText == "")
        #expect(viewModel.documentErrorMessage == nil)
        #expect(viewModel.documentImportSuccessMessage == nil)
        #expect(viewModel.isShowingDocumentImporter == false)
        #expect(viewModel.isShowingDocumentScanner == false)
        #expect(viewModel.isImportingDocument == false)
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
        #expect(viewModel.hasSourceDocument == false)
    }

    @Test @MainActor func documentDetailShowsAndCleansUpOriginalPreview() throws {
        let sourceData = Data("original pdf".utf8)
        let previewURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("document-preview.pdf")
        let previewService = TravelDocumentSourcePreviewServiceStub(
            result: .success(previewURL)
        )
        let document = TravelDocument(
            title: "Boarding Pass",
            fileName: "boarding-pass.pdf",
            sourceData: sourceData
        )
        let viewModel = TravelDocumentDetailViewModel(
            document: document,
            travelDocumentSourcePreviewService: previewService
        )

        #expect(viewModel.hasSourceDocument)

        viewModel.showSourcePreview(for: document)

        #expect(viewModel.isShowingSourcePreview)
        #expect(viewModel.sourcePreviewURL == previewURL)
        #expect(viewModel.sourcePreviewErrorMessage == nil)
        #expect(previewService.receivedData == sourceData)
        #expect(previewService.receivedFileName == "boarding-pass.pdf")

        viewModel.dismissSourcePreview()

        #expect(viewModel.isShowingSourcePreview == false)
        #expect(viewModel.sourcePreviewURL == nil)
        #expect(previewService.removedURL == previewURL)
    }

    @Test @MainActor func documentDetailExplainsMissingOriginalPreview() {
        let document = TravelDocument(title: "Manuelle Notiz")
        let viewModel = TravelDocumentDetailViewModel(document: document)

        viewModel.showSourcePreview(for: document)

        #expect(viewModel.isShowingSourcePreview == false)
        #expect(viewModel.sourcePreviewURL == nil)
        #expect(viewModel.sourcePreviewErrorMessage == "Fuer diese Reiseunterlage ist keine Originaldatei gespeichert.")
    }

    @Test @MainActor func documentDetailSharesAndCleansUpOriginalFile() {
        let sourceData = Data("original pdf".utf8)
        let exportURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("boarding-pass.pdf")
        let previewService = TravelDocumentSourcePreviewServiceStub(
            result: .success(exportURL)
        )
        let document = TravelDocument(
            title: "Boarding Pass",
            fileName: "boarding-pass.pdf",
            sourceData: sourceData
        )
        let viewModel = TravelDocumentDetailViewModel(
            document: document,
            travelDocumentSourcePreviewService: previewService
        )

        viewModel.showSourceShare(for: document)

        #expect(viewModel.isShowingSourceShare)
        #expect(viewModel.sourceShareURL == exportURL)
        #expect(viewModel.sourceShareErrorMessage == nil)
        #expect(previewService.receivedExportData == sourceData)
        #expect(previewService.receivedExportFileName == "boarding-pass.pdf")

        viewModel.dismissSourceShare()

        #expect(viewModel.isShowingSourceShare == false)
        #expect(viewModel.sourceShareURL == nil)
        #expect(previewService.removedExportURL == exportURL)
    }

    @Test @MainActor func documentDetailExplainsMissingOriginalForSharing() {
        let document = TravelDocument(title: "Manuelle Notiz")
        let viewModel = TravelDocumentDetailViewModel(document: document)

        viewModel.showSourceShare(for: document)

        #expect(viewModel.isShowingSourceShare == false)
        #expect(viewModel.sourceShareURL == nil)
        #expect(viewModel.sourceShareErrorMessage == "Fuer diese Reiseunterlage ist keine Originaldatei gespeichert.")
    }

    @Test @MainActor func documentDetailPreparesImportedSourceReplacementWithoutChangingDocument() async {
        let oldSourceData = Data("old source".utf8)
        let newSourceData = Data("new source".utf8)
        let document = TravelDocument(
            title: "Boarding Pass",
            fileName: "old-ticket.pdf",
            extractedText: "Alter OCR-Text",
            sourceData: oldSourceData,
            sourceFingerprint: "old-fingerprint"
        )
        let viewModel = TravelDocumentDetailViewModel(
            document: document,
            travelDocumentOCRService: TravelDocumentOCRServiceStub(
                recognizedText: "Flug LH 2034 am 05.08.2026 um 09:05"
            ),
            travelDocumentSourceService: TravelDocumentSourceServiceStub(
                sourceData: newSourceData,
                sourceFingerprint: "new-fingerprint"
            )
        )

        await viewModel.importSourceReplacement(
            from: .success([URL(fileURLWithPath: "/tmp/new-ticket.pdf")])
        )

        #expect(viewModel.isShowingSourceReplacementReview)
        #expect(viewModel.sourceReplacementFileName == "new-ticket.pdf")
        #expect(viewModel.sourceReplacementExtractedText == "Flug LH 2034 am 05.08.2026 um 09:05")
        #expect(viewModel.canConfirmSourceReplacement)
        #expect(document.fileName == "old-ticket.pdf")
        #expect(document.extractedText == "Alter OCR-Text")
        #expect(document.sourceData == oldSourceData)
        #expect(document.sourceFingerprint == "old-fingerprint")
    }

    @Test @MainActor func documentDetailCancelsSourceReplacementWithoutChangingDocument() async {
        let oldSourceData = Data("old source".utf8)
        let document = TravelDocument(
            title: "Boarding Pass",
            fileName: "old-ticket.pdf",
            extractedText: "Alter OCR-Text",
            sourceData: oldSourceData,
            sourceFingerprint: "old-fingerprint"
        )
        let viewModel = TravelDocumentDetailViewModel(
            document: document,
            travelDocumentOCRService: TravelDocumentOCRServiceStub(recognizedText: "Neuer OCR-Text"),
            travelDocumentSourceService: TravelDocumentSourceServiceStub()
        )

        await viewModel.importSourceReplacement(
            from: .success([URL(fileURLWithPath: "/tmp/new-ticket.pdf")])
        )
        viewModel.cancelSourceReplacementReview()

        #expect(viewModel.isShowingSourceReplacementReview == false)
        #expect(viewModel.canConfirmSourceReplacement == false)
        #expect(viewModel.sourceReplacementFileName.isEmpty)
        #expect(viewModel.sourceReplacementExtractedText.isEmpty)
        #expect(document.fileName == "old-ticket.pdf")
        #expect(document.extractedText == "Alter OCR-Text")
        #expect(document.sourceData == oldSourceData)
        #expect(document.sourceFingerprint == "old-fingerprint")
    }

    @Test @MainActor func documentDetailReplacesSourceOnlyAfterReviewConfirmation() async {
        let oldSourceData = Data("old source".utf8)
        let newSourceData = Data("new source".utf8)
        let document = TravelDocument(
            title: "Boarding Pass",
            fileName: "old-ticket.pdf",
            extractedText: "Alter OCR-Text",
            sourceData: oldSourceData,
            sourceFingerprint: "old-fingerprint"
        )
        let viewModel = TravelDocumentDetailViewModel(
            document: document,
            travelDocumentOCRService: TravelDocumentOCRServiceStub(recognizedText: "Erkannter Text"),
            travelDocumentSourceService: TravelDocumentSourceServiceStub(
                sourceData: newSourceData,
                sourceFingerprint: "new-fingerprint"
            )
        )

        await viewModel.importSourceReplacement(
            from: .success([URL(fileURLWithPath: "/tmp/new-ticket.pdf")])
        )
        viewModel.sourceReplacementExtractedText = "Korrigierter OCR-Text"
        viewModel.confirmSourceReplacement(for: document)

        #expect(viewModel.isShowingSourceReplacementReview == false)
        #expect(viewModel.sourceReplacementSuccessMessage == "Die Originaldatei wurde ersetzt.")
        #expect(viewModel.fileName == "new-ticket.pdf")
        #expect(viewModel.extractedText == "Korrigierter OCR-Text")
        #expect(document.fileName == "new-ticket.pdf")
        #expect(document.extractedText == "Korrigierter OCR-Text")
        #expect(document.sourceData == newSourceData)
        #expect(document.sourceFingerprint == "new-fingerprint")
    }

    @Test @MainActor func documentDetailRejectsDuplicateSourceReplacementWithoutChangingDocument() async throws {
        let oldSourceData = Data("old source".utf8)
        let duplicateSourceData = Data("duplicate source".utf8)
        let trip = try tripService.createTrip(title: "Berlin")
        let document = try travelDocumentService.createDocument(
            title: "Boarding Pass",
            fileName: "old-ticket.pdf",
            extractedText: "Alter OCR-Text",
            sourceData: oldSourceData,
            sourceFingerprint: "old-fingerprint",
            for: trip
        )
        _ = try travelDocumentService.createDocument(
            title: "Hotel",
            sourceData: duplicateSourceData,
            sourceFingerprint: "duplicate-fingerprint",
            for: trip
        )
        let viewModel = TravelDocumentDetailViewModel(
            document: document,
            travelDocumentOCRService: TravelDocumentOCRServiceStub(recognizedText: "Neuer OCR-Text"),
            travelDocumentSourceService: TravelDocumentSourceServiceStub(
                sourceData: duplicateSourceData,
                sourceFingerprint: "duplicate-fingerprint"
            )
        )

        await viewModel.importSourceReplacement(
            from: .success([URL(fileURLWithPath: "/tmp/duplicate.pdf")])
        )
        viewModel.confirmSourceReplacement(for: document)

        #expect(viewModel.isShowingSourceReplacementReview)
        #expect(viewModel.sourceReplacementErrorMessage == "Diese Originaldatei ist in diesem Trip bereits gespeichert.")
        #expect(document.fileName == "old-ticket.pdf")
        #expect(document.extractedText == "Alter OCR-Text")
        #expect(document.sourceData == oldSourceData)
        #expect(document.sourceFingerprint == "old-fingerprint")
    }

    @Test @MainActor func documentDetailPreparesScannedSourceReplacementForReview() async {
        let newSourceData = Data("scan pdf".utf8)
        let document = TravelDocument(
            title: "Boarding Pass",
            sourceData: Data("old source".utf8),
            sourceFingerprint: "old-fingerprint"
        )
        let viewModel = TravelDocumentDetailViewModel(
            document: document,
            travelDocumentOCRService: TravelDocumentOCRServiceStub(recognizedText: "Scan OCR-Text"),
            travelDocumentSourceService: TravelDocumentSourceServiceStub(
                sourceData: newSourceData,
                sourceFingerprint: "scan-fingerprint"
            )
        )
        viewModel.isShowingSourceReplacementScanner = true

        await viewModel.importScannedSourceReplacementPages([Data([1]), Data([2])])

        #expect(viewModel.isShowingSourceReplacementScanner == false)
        #expect(viewModel.isShowingSourceReplacementReview)
        #expect(viewModel.sourceReplacementFileName == "Dokumentenscan.pdf")
        #expect(viewModel.sourceReplacementExtractedText == "Scan OCR-Text")
        #expect(document.sourceFingerprint == "old-fingerprint")
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

    @Test func documentDetailParsesDocumentReferenceMetadata() {
        let document = TravelDocument(
            title: "Boarding Pass",
            extractedText: """
            Boarding LH 2034 Gate A12 05/08/26 09:05
            Buchungsnummer: XYZ789
            """
        )
        let viewModel = TravelDocumentDetailViewModel(document: document)

        #expect(viewModel.hasParsedTravelData(calendar: testCalendar()))
        #expect(viewModel.parsedFlightNumber(calendar: testCalendar()) == "LH2034")
        #expect(viewModel.parsedReservationNumber(calendar: testCalendar()) == "XYZ789")
    }

    @Test func documentDetailBuildsRecognitionSummaryItems() {
        let document = TravelDocument(
            title: "Boarding Pass",
            extractedText: """
            Boarding LH 2034 Gate A12 05/08/26 09:05
            Adresse: Gate A12
            Buchungsnummer: XYZ789
            """
        )
        let viewModel = TravelDocumentDetailViewModel(document: document)

        let items = viewModel.recognitionSummaryItems(calendar: testCalendar())

        #expect(items.map(\.id) == ["stopTitle", "schedule", "location", "reference"])
        #expect(items.first { $0.id == "stopTitle" }?.value == "Flug LH2034")
        #expect(items.first { $0.id == "schedule" }?.value == "5. August 2026, 09:05")
        #expect(items.first { $0.id == "location" }?.value == "Gate A12")
        #expect(items.first { $0.id == "reference" }?.value == "Flug LH2034 - Ref XYZ789")
    }

    @Test func documentDetailUsesArrivalForReviewedRouteStopSuggestion() throws {
        let trip = try tripService.createTrip(title: "Europa")
        let document = try travelDocumentService.createDocument(
            title: "Bahnticket",
            extractedText: """
            Bahn ICE 100
            Von: Berlin Hbf
            Abfahrt: 15.07.2026 08:30
            Nach: Hamburg Hbf
            Ankunft: 15.07.2026 10:45
            """,
            for: trip
        )
        let viewModel = TravelDocumentDetailViewModel(document: document)

        let items = viewModel.recognitionSummaryItems(calendar: testCalendar())
        viewModel.showStopSuggestion(from: document, calendar: testCalendar())

        #expect(items.map(\.id) == ["stopTitle", "departure", "departureSchedule", "arrival", "arrivalSchedule", "reference"])
        #expect(viewModel.parsedDepartureLocationName(calendar: testCalendar()) == "Berlin Hbf")
        #expect(viewModel.parsedArrivalLocationName(calendar: testCalendar()) == "Hamburg Hbf")
        #expect(viewModel.parsedDepartureScheduleText(calendar: testCalendar()) == "15. Juli 2026, 08:30")
        #expect(viewModel.parsedArrivalScheduleText(calendar: testCalendar()) == "15. Juli 2026, 10:45")
        #expect(viewModel.stopSuggestionLocationName == "Hamburg Hbf")
        #expect(viewModel.stopSuggestionScheduledDate == makeDate(year: 2026, month: 7, day: 15, hour: 10, minute: 45, calendar: testCalendar()))
    }

    @Test func documentDetailExplainsMissingArrivalTimeForCompleteRoute() throws {
        let trip = try tripService.createTrip(title: "Europa")
        let document = try travelDocumentService.createDocument(
            title: "Bahnticket",
            extractedText: """
            Bahn ICE 100 15.07.2026 08:30
            Von: Berlin Hbf
            Nach: Hamburg Hbf
            """,
            for: trip
        )
        let viewModel = TravelDocumentDetailViewModel(document: document)

        #expect(viewModel.canShowStopSuggestionAction(for: document, calendar: testCalendar()) == false)
        #expect(
            viewModel.stopSuggestionUnavailableMessage(for: document, calendar: testCalendar())
                == "Kein Stop-Vorschlag: Fuer das erkannte Ziel fehlt noch eine Ankunftszeit."
        )
    }

    @Test func documentDetailParsesTrainNumberMetadata() {
        let document = TravelDocument(
            title: "Bahnticket",
            extractedText: "Bahn ICE 100 Berlin Hbf 15.07.2026 08:30"
        )
        let viewModel = TravelDocumentDetailViewModel(document: document)

        #expect(viewModel.hasParsedTravelData(calendar: testCalendar()))
        #expect(viewModel.parsedTrainNumber(calendar: testCalendar()) == "ICE100")
    }

    @Test func documentDetailReportsEmptyExtractedTextState() {
        let document = TravelDocument(title: "Hotel", extractedText: "   ")
        let viewModel = TravelDocumentDetailViewModel(document: document)

        #expect(viewModel.hasExtractedText == false)

        viewModel.extractedText = "  Check-in 15:00  "

        #expect(viewModel.hasExtractedText)
    }

    @Test func documentDetailExplainsMissingStopSuggestionDate() throws {
        let trip = try tripService.createTrip(title: "Berlin")
        let document = try travelDocumentService.createDocument(
            title: "Reservierung",
            extractedText: "Reservierung ABC123 ohne Datum",
            for: trip
        )
        let viewModel = TravelDocumentDetailViewModel(document: document)

        #expect(
            viewModel.stopSuggestionUnavailableMessage(for: document, calendar: testCalendar())
                == "Kein Stop-Vorschlag: Im OCR-Text wurde noch kein Datum erkannt."
        )
    }

    @Test func documentDetailDoesNotExplainMissingStopSuggestionWhenDateExists() throws {
        let trip = try tripService.createTrip(title: "Berlin")
        let document = try travelDocumentService.createDocument(
            title: "Hotel",
            extractedText: "Check-in 15.07.2026 ab 14:30 Uhr",
            for: trip
        )
        let viewModel = TravelDocumentDetailViewModel(document: document)

        #expect(viewModel.stopSuggestionUnavailableMessage(for: document, calendar: testCalendar()) == nil)
    }

    @Test func documentDetailPreparesStopSuggestionFromParsedData() throws {
        let trip = try tripService.createTrip(title: "Berlin")
        let document = try travelDocumentService.createDocument(
            title: "Importierte Unterlage",
            extractedText: """
            Boarding LH 2034 Gate A12 05/08/26 09:05
            Buchungsnummer: XYZ789
            """,
            for: trip
        )
        let viewModel = TravelDocumentDetailViewModel(document: document)

        viewModel.showStopSuggestion(from: document, calendar: testCalendar())

        #expect(viewModel.isShowingStopSuggestion)
        #expect(viewModel.stopSuggestionTitle == "Flug LH2034")
        #expect(viewModel.stopSuggestionLocationName == "")
        #expect(viewModel.stopSuggestionScheduledDate == makeDate(year: 2026, month: 8, day: 5, hour: 9, minute: 5, calendar: testCalendar()))
        #expect(viewModel.stopSuggestionDocumentType == "")
        #expect(viewModel.stopSuggestionTextExcerpt == "Boarding LH 2034 Gate A12 05/08/26 09:05\nBuchungsnummer: XYZ789")
        #expect(viewModel.stopSuggestionFlightNumber == "LH2034")
        #expect(viewModel.stopSuggestionReservationNumber == "XYZ789")
        #expect(viewModel.canCreateStopSuggestion)
    }

    @Test func documentDetailPreparesTrainNumberForStopSuggestion() throws {
        let trip = try tripService.createTrip(title: "Berlin")
        let document = try travelDocumentService.createDocument(
            title: "Bahnticket",
            extractedText: "Bahn ICE 100 Berlin Hbf 15.07.2026 08:30",
            for: trip
        )
        let viewModel = TravelDocumentDetailViewModel(document: document)

        viewModel.showStopSuggestion(from: document, calendar: testCalendar())

        #expect(viewModel.stopSuggestionTrainNumber == "ICE100")
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
        #expect(viewModel.stopSuggestionSuccessMessage == "Stop \"Hotel Check-in\" wurde aus der Reiseunterlage erstellt.")
    }

    @Test @MainActor func documentDetailRejectsStopSuggestionWithoutTitle() throws {
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
        viewModel.stopSuggestionTitle = "   "

        #expect(viewModel.canCreateStopSuggestion == false)
        #expect(viewModel.createStopSuggestionDisabledReason == "Name fuer den vorgeschlagenen Stop fehlt.")

        viewModel.createStopSuggestion(from: document, in: modelContext)

        #expect(trip.stops.isEmpty)
        #expect(viewModel.stopSuggestionErrorMessage == "Bitte gib einen Namen fuer den vorgeschlagenen Stop ein.")
        #expect(viewModel.isShowingStopSuggestion)
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

    @Test func documentDetailCancelsStopSuggestionCleanly() throws {
        let trip = try tripService.createTrip(title: "Berlin")
        let document = try travelDocumentService.createDocument(
            title: "Importierte Unterlage",
            documentType: "Hotel",
            extractedText: "Check-in 15.07.2026 ab 14:30 Uhr Reservierung: ABC12345",
            for: trip
        )
        let viewModel = TravelDocumentDetailViewModel(document: document)
        viewModel.showStopSuggestion(from: document, calendar: testCalendar())
        viewModel.stopSuggestionErrorMessage = "Fehler"

        viewModel.cancelStopSuggestionReview()

        #expect(viewModel.isShowingStopSuggestion == false)
        #expect(viewModel.stopSuggestionTitle == "")
        #expect(viewModel.stopSuggestionScheduledDate == nil)
        #expect(viewModel.stopSuggestionDocumentType == "")
        #expect(viewModel.stopSuggestionReservationNumber == "")
        #expect(viewModel.stopSuggestionErrorMessage == nil)
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
        viewModel.errorMessage = "Alter Fehler"

        viewModel.save(document: document)

        #expect(document.title == "Hotelbuchung")
        #expect(document.documentType == "Hotel")
        #expect(document.fileName == "hotel.pdf")
        #expect(document.extractedText == "Check-in 15:00")
        #expect(viewModel.errorMessage == nil)
    }

    @Test func documentDetailExplainsDisabledSaveWithoutTitle() {
        let document = TravelDocument(title: "Hotel")
        let viewModel = TravelDocumentDetailViewModel(document: document)
        viewModel.title = "   "

        #expect(viewModel.canSave == false)
        #expect(viewModel.saveDisabledReason == "Name fuer die Reiseunterlage fehlt.")
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

    @Test func stopDetailExplainsDisabledSaveWithoutTitle() throws {
        let trip = try tripService.createTrip(title: "Berlin")
        let stop = try stopService.createStop(title: "Hotel", locationName: "", for: trip)
        let viewModel = StopDetailViewModel(stop: stop)
        viewModel.title = "   "

        #expect(viewModel.canSave == false)
        #expect(viewModel.saveDisabledReason == "Name fuer den Stop fehlt.")
    }

    @Test func stopDetailSaveClearsOldErrorOnNewAttempt() throws {
        let trip = try tripService.createTrip(title: "Berlin")
        let stop = try stopService.createStop(title: "Hotel", locationName: "", for: trip)
        let viewModel = StopDetailViewModel(stop: stop)
        viewModel.title = "Museum"
        viewModel.errorMessage = "Alter Fehler"

        viewModel.save(stop: stop)

        #expect(stop.title == "Museum")
        #expect(viewModel.errorMessage == nil)
    }

    @Test func stopDetailSummarizesOpenPlanningValues() {
        let viewModel = StopDetailViewModel(stop: Stop(title: "Hotel"))

        #expect(viewModel.scheduleSummaryText == "Zeitpunkt offen")
        #expect(viewModel.scheduledDateText == nil)
        #expect(viewModel.locationSummaryText == "Ort offen")
        #expect(viewModel.coordinateSummaryText == "Koordinaten offen")
    }

    @Test func stopDetailFormatsScheduledDateInGerman() {
        let calendar = Calendar.current
        let stop = Stop(
            title: "Hotel",
            scheduledDate: makeDate(year: 2026, month: 7, day: 15, hour: 14, minute: 30, calendar: calendar)
        )
        let viewModel = StopDetailViewModel(stop: stop)

        #expect(viewModel.scheduleSummaryText == "Geplant")
        #expect(viewModel.scheduledDateText == "15. Juli 2026, 14:30")
    }

    @Test func stopDetailSummarizesEditedLocationAndCoordinates() {
        let viewModel = StopDetailViewModel(stop: Stop(title: "Hotel"))
        viewModel.locationName = "  Berlin Mitte  "
        viewModel.latitudeText = " 52.52 "
        viewModel.longitudeText = " 13.405 "

        #expect(viewModel.locationSummaryText == "Berlin Mitte")
        #expect(viewModel.coordinateSummaryText == "52.52, 13.405")
    }

    @Test func stopDetailSummarizesPartialCoordinates() {
        let viewModel = StopDetailViewModel(stop: Stop(title: "Hotel"))
        viewModel.latitudeText = "52.52"
        viewModel.longitudeText = "   "

        #expect(viewModel.coordinateSummaryText == "Koordinaten unvollstaendig")
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
        viewModel.stopErrorMessage = "Alter Fehler"

        await viewModel.fillNewStopCoordinatesFromLocationName()

        #expect(viewModel.newStopLatitudeText == "52.52")
        #expect(viewModel.newStopLongitudeText == "13.405")
        #expect(viewModel.stopErrorMessage == nil)
    }

    @Test func tripDetailExplainsDisabledNewStopCoordinateLookupWithoutLocation() {
        let viewModel = TripDetailViewModel(trip: Trip(title: "Berlin"))
        viewModel.newStopLocationName = "   "

        #expect(viewModel.canFillNewStopCoordinatesFromLocationName == false)
        #expect(viewModel.newStopCoordinateLookupDisabledReason == "Ort fuer die Koordinatensuche fehlt.")
    }

    @Test func tripDetailExplainsDisabledDocumentStopCoordinateLookupWithoutRecognizedLocation() {
        let viewModel = TripDetailViewModel(trip: Trip(title: "Berlin"))
        viewModel.isReviewingDocumentStopSuggestion = true
        viewModel.newStopLocationName = "   "

        #expect(viewModel.canFillNewStopCoordinatesFromLocationName == false)
        #expect(viewModel.newStopCoordinateLookupDisabledReason == "Erkannter Ort fuer die Koordinatensuche fehlt.")
    }

    @Test func tripDetailExplainsDisabledNewStopCoordinateLookupWhileResolving() {
        let viewModel = TripDetailViewModel(trip: Trip(title: "Berlin"))
        viewModel.newStopLocationName = "Berlin"
        viewModel.isResolvingNewStopCoordinates = true

        #expect(viewModel.canFillNewStopCoordinatesFromLocationName == false)
        #expect(viewModel.newStopCoordinateLookupDisabledReason == "Koordinaten werden gesucht.")
    }

    @Test @MainActor func stopDetailGeocodingFillsCoordinates() async {
        let stop = Stop(title: "Hotel", locationName: "Berlin")
        let viewModel = StopDetailViewModel(
            stop: stop,
            geocodingService: StubLocationGeocodingService(
                result: .success(GeocodedCoordinate(latitude: 52.52, longitude: 13.405))
            )
        )
        viewModel.errorMessage = "Alter Fehler"

        await viewModel.fillCoordinatesFromLocationName()

        #expect(viewModel.latitudeText == "52.52")
        #expect(viewModel.longitudeText == "13.405")
        #expect(viewModel.errorMessage == nil)
    }

    @Test func stopDetailExplainsDisabledCoordinateLookupWithoutLocation() {
        let viewModel = StopDetailViewModel(stop: Stop(title: "Hotel"))
        viewModel.locationName = "   "

        #expect(viewModel.canFillCoordinatesFromLocationName == false)
        #expect(viewModel.coordinateLookupDisabledReason == "Ort fuer die Koordinatensuche fehlt.")
    }

    @Test func stopDetailExplainsDisabledCoordinateLookupWhileResolving() {
        let viewModel = StopDetailViewModel(stop: Stop(title: "Hotel", locationName: "Berlin"))
        viewModel.isResolvingCoordinates = true

        #expect(viewModel.canFillCoordinatesFromLocationName == false)
        #expect(viewModel.coordinateLookupDisabledReason == "Koordinaten werden gesucht.")
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

private struct TravelDocumentOCRServiceStub: TravelDocumentTextRecognizing {
    let recognizedText: String?
    let error: TravelDocumentOCRError?

    init(recognizedText: String) {
        self.recognizedText = recognizedText
        error = nil
    }

    init(error: TravelDocumentOCRError) {
        recognizedText = nil
        self.error = error
    }

    func recognizeText(inDocumentAt url: URL) async throws -> String {
        if let error {
            throw error
        }

        return recognizedText ?? ""
    }

    func recognizeText(inImageData pages: [Data]) async throws -> String {
        if let error {
            throw error
        }

        return recognizedText ?? ""
    }
}

private struct TravelDocumentSourceServiceStub: TravelDocumentSourcePreparing {
    let sourceData: Data
    let validationError: TravelDocumentSourceError?
    let sourceFingerprint: String

    init(
        sourceData: Data = Data("source".utf8),
        validationError: TravelDocumentSourceError? = nil,
        sourceFingerprint: String = "source-fingerprint"
    ) {
        self.sourceData = sourceData
        self.validationError = validationError
        self.sourceFingerprint = sourceFingerprint
    }

    func validateDocument(at url: URL) throws {
        if let validationError {
            throw validationError
        }
    }

    func validateScannedPages(_ pages: [Data]) throws {
        if let validationError {
            throw validationError
        }
    }

    func data(from url: URL) throws -> Data {
        sourceData
    }

    func pdfData(fromScannedPages pages: [Data]) throws -> Data {
        sourceData
    }

    func fingerprint(for data: Data) -> String {
        sourceFingerprint
    }
}

@MainActor
private final class TravelDocumentSourcePreviewServiceStub: TravelDocumentSourcePreviewing {
    let result: Result<URL, Error>
    private(set) var receivedData: Data?
    private(set) var receivedFileName: String?
    private(set) var removedURL: URL?
    private(set) var receivedExportData: Data?
    private(set) var receivedExportFileName: String?
    private(set) var removedExportURL: URL?

    init(result: Result<URL, Error>) {
        self.result = result
    }

    func temporaryPreviewURL(for data: Data, fileName: String) throws -> URL {
        receivedData = data
        receivedFileName = fileName
        return try result.get()
    }

    func removeTemporaryPreview(at url: URL) {
        removedURL = url
    }

    func temporaryExportURL(for data: Data, fileName: String) throws -> URL {
        receivedExportData = data
        receivedExportFileName = fileName
        return try result.get()
    }

    func removeTemporaryExport(at url: URL) {
        removedExportURL = url
    }
}

private struct StubLocationGeocodingService: LocationGeocoding {
    let result: Result<GeocodedCoordinate, Error>

    func coordinate(for query: String) async throws -> GeocodedCoordinate {
        try result.get()
    }
}
