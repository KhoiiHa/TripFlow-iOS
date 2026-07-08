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
    var stopSuccessMessage: String?
    var isResolvingNewStopCoordinates = false
    var isReviewingDocumentStopSuggestion = false
    var stopSuggestionDocumentType = ""
    var stopSuggestionTextExcerpt = ""
    var stopSuggestionFlightNumber = ""
    var stopSuggestionReservationNumber = ""
    var newDocumentTitle = ""
    var newDocumentType = ""
    var newDocumentFileName = ""
    var newDocumentExtractedText = ""
    var isShowingCreateDocument = false
    var documentErrorMessage: String?

    var canSave: Bool {
        title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    }

    var canCreateStop: Bool {
        newStopTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    }

    var canCreateDocument: Bool {
        newDocumentTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    }

    var newDocumentExtractedTextHint: String {
        "Eingefuegter OCR-Text wird nach dem Speichern fuer erkannte Reisedaten und Stop-Vorschlaege genutzt."
    }

    private let tripService: TripService
    private let stopService: StopService
    private let travelDocumentService: TravelDocumentService
    private let travelDocumentParserService: TravelDocumentParserService
    private let timelineService: TimelineService
    private let mapService: MapService
    private let geocodingService: any LocationGeocoding

    init(
        trip: Trip,
        tripService: TripService = TripService(),
        stopService: StopService = StopService(),
        travelDocumentService: TravelDocumentService = TravelDocumentService(),
        travelDocumentParserService: TravelDocumentParserService = TravelDocumentParserService(),
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
        self.travelDocumentService = travelDocumentService
        self.travelDocumentParserService = travelDocumentParserService
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

    func sortedDocuments(for trip: Trip) -> [TravelDocument] {
        trip.documents.sorted {
            if $0.createdAt == $1.createdAt {
                return $0.title.localizedStandardCompare($1.title) == .orderedAscending
            }

            return $0.createdAt > $1.createdAt
        }
    }

    func documentSubtitle(for document: TravelDocument) -> String? {
        var details: [String] = []

        if document.documentType.isEmpty == false {
            details.append(document.documentType)
        }

        if document.fileName.isEmpty == false {
            details.append(document.fileName)
        }

        let parseResult = travelDocumentParserService.parse(document.extractedText)

        if let flightNumber = parseResult.flightNumber {
            details.append("Flug \(flightNumber)")
        }

        if let reservationNumber = parseResult.reservationNumber {
            details.append("Ref \(reservationNumber)")
        }

        if let suggestedLocationName = parseResult.suggestedLocationName {
            details.append("Ort \(suggestedLocationName)")
        }

        if let parsedDateText = Self.parsedDateText(from: parseResult) {
            details.append(parsedDateText)
        }

        let hasExtractedText = document.extractedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
        details.append(hasExtractedText ? "OCR vorhanden" : "OCR offen")

        return details.isEmpty ? nil : details.joined(separator: " - ")
    }

    func parsedScheduleDate(for document: TravelDocument, calendar: Calendar = .current) -> Date? {
        travelDocumentParserService.parse(document.extractedText, calendar: calendar).scheduledDate
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
        stopSuccessMessage = nil
        isResolvingNewStopCoordinates = false
        isReviewingDocumentStopSuggestion = false
        stopSuggestionDocumentType = ""
        stopSuggestionTextExcerpt = ""
        stopSuggestionFlightNumber = ""
        stopSuggestionReservationNumber = ""
        isShowingCreateStop = true
    }

    func showCreateStop(from document: TravelDocument, calendar: Calendar = .current) {
        showCreateStop()
        let parseResult = travelDocumentParserService.parse(document.extractedText, calendar: calendar)
        newStopTitle = parseResult.suggestedStopTitle ?? document.title
        newStopLocationName = parseResult.suggestedLocationName ?? ""
        isReviewingDocumentStopSuggestion = true
        stopSuggestionDocumentType = document.documentType
        stopSuggestionTextExcerpt = Self.textExcerpt(from: document.extractedText)
        stopSuggestionFlightNumber = parseResult.flightNumber ?? ""
        stopSuggestionReservationNumber = parseResult.reservationNumber ?? ""

        if let scheduledDate = parseResult.scheduledDate {
            newStopScheduledDate = scheduledDate
            newStopHasScheduledDate = true
        }
    }

    func showCreateDocument() {
        newDocumentTitle = ""
        newDocumentType = ""
        newDocumentFileName = ""
        newDocumentExtractedText = ""
        documentErrorMessage = nil
        isShowingCreateDocument = true
    }

    func setNewStopScheduledDateEnabled(_ isEnabled: Bool) {
        newStopHasScheduledDate = isEnabled
        newStopScheduledDate = isEnabled ? (newStopScheduledDate ?? startDate ?? Date()) : nil
    }

    func createStop(for trip: Trip, in modelContext: ModelContext) {
        do {
            guard isReviewingDocumentStopSuggestion == false || (newStopHasScheduledDate && newStopScheduledDate != nil) else {
                stopErrorMessage = "Bitte pruefe Datum und Uhrzeit fuer den vorgeschlagenen Stop."
                return
            }

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
            stopSuccessMessage = "Stop \"\(stop.title)\" wurde erstellt."
            isShowingCreateStop = false
            isReviewingDocumentStopSuggestion = false
            stopSuggestionDocumentType = ""
            stopSuggestionTextExcerpt = ""
            stopSuggestionFlightNumber = ""
            stopSuggestionReservationNumber = ""
        } catch StopValidationError.emptyTitle {
            stopErrorMessage = "Bitte gib einen Namen fuer den Stop ein."
        } catch StopValidationError.invalidCoordinates {
            stopErrorMessage = "Bitte gib gueltige Koordinaten ein."
        } catch {
            stopErrorMessage = "Der Stop konnte nicht erstellt werden."
        }
    }

    func createDocument(for trip: Trip, in modelContext: ModelContext) {
        do {
            let document = try travelDocumentService.createDocument(
                title: newDocumentTitle,
                documentType: newDocumentType,
                fileName: newDocumentFileName,
                extractedText: newDocumentExtractedText,
                for: trip
            )
            modelContext.insert(document)
            newDocumentTitle = ""
            newDocumentType = ""
            newDocumentFileName = ""
            newDocumentExtractedText = ""
            documentErrorMessage = nil
            isShowingCreateDocument = false
        } catch TravelDocumentValidationError.emptyTitle {
            documentErrorMessage = "Bitte gib einen Namen fuer die Reiseunterlage ein."
        } catch {
            documentErrorMessage = "Die Reiseunterlage konnte nicht erstellt werden."
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

    func deleteDocuments(_ documents: [TravelDocument], at offsets: IndexSet, from trip: Trip, in modelContext: ModelContext) {
        for index in offsets {
            let document = documents[index]

            if let tripDocumentIndex = trip.documents.firstIndex(where: { $0 === document }) {
                trip.documents.remove(at: tripDocumentIndex)
            }

            modelContext.delete(document)
        }

        trip.updatedAt = Date()
    }

    private static func coordinateText(_ coordinate: Double) -> String {
        String(coordinate)
    }

    private static func textExcerpt(from text: String) -> String {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)

        guard trimmedText.count > 120 else {
            return trimmedText
        }

        return String(trimmedText.prefix(120)) + "..."
    }

    private static func parsedDateText(from parseResult: TravelDocumentParseResult) -> String? {
        guard let date = parseResult.date else {
            return nil
        }

        let dateText = String(format: "%02d.%02d.%04d", date.day, date.month, date.year)

        guard let time = parseResult.time else {
            return dateText
        }

        return dateText + " " + String(format: "%02d:%02d", time.hour, time.minute)
    }
}
