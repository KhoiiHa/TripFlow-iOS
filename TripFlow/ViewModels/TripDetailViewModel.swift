//
//  TripDetailViewModel.swift
//  TripFlow
//
//  Created by Vu Minh Khoi Ha on 06.07.26.
//

import Foundation
import MapKit
import SwiftData

struct DocumentMetadataBadge: Equatable, Identifiable {
    let title: String
    let systemImage: String
    let isHighlighted: Bool

    var id: String {
        "\(systemImage)-\(title)"
    }
}

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
    var stopSuggestionTrainNumber = ""
    var stopSuggestionReservationNumber = ""
    var newDocumentTitle = ""
    var newDocumentType = ""
    var newDocumentFileName = ""
    var newDocumentExtractedText = ""
    var isShowingCreateDocument = false
    var isShowingDocumentImporter = false
    var isShowingDocumentScanner = false
    var isImportingDocument = false
    var documentErrorMessage: String?
    var documentImportSuccessMessage: String?
    private var pendingDocumentStopSuggestion: TravelDocument?

    var canSave: Bool {
        saveDisabledReason == nil
    }

    var saveDisabledReason: String? {
        if title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Name fuer den Trip fehlt."
        }

        if hasStartDate,
           hasEndDate,
           let startDate,
           let endDate,
           endDate < startDate {
            return "Enddatum darf nicht vor dem Startdatum liegen."
        }

        return nil
    }

    var canCreateStop: Bool {
        createStopDisabledReason == nil
    }

    var createStopDisabledReason: String? {
        if newStopTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return isReviewingDocumentStopSuggestion
                ? "Name fuer den vorgeschlagenen Stop fehlt."
                : "Name fuer den Stop fehlt."
        }

        if isReviewingDocumentStopSuggestion && (newStopHasScheduledDate == false || newStopScheduledDate == nil) {
            return "Datum und Uhrzeit fuer den vorgeschlagenen Stop fehlen."
        }

        return nil
    }

    var canCreateDocument: Bool {
        createDocumentDisabledReason == nil
    }

    var createDocumentDisabledReason: String? {
        if isImportingDocument {
            return "Texterkennung laeuft."
        }

        if newDocumentTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Name fuer die Reiseunterlage fehlt."
        }

        return nil
    }

    var newDocumentTypeSuggestions: [String] {
        ["Flug", "Hotel", "Bahn", "Reservierung", "Ticket"]
    }

    var canFillNewStopCoordinatesFromLocationName: Bool {
        newStopCoordinateLookupDisabledReason == nil
    }

    var newStopCoordinateLookupDisabledReason: String? {
        if isResolvingNewStopCoordinates {
            return "Koordinaten werden gesucht."
        }

        if newStopLocationName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return isReviewingDocumentStopSuggestion
                ? "Erkannter Ort fuer die Koordinatensuche fehlt."
                : "Ort fuer die Koordinatensuche fehlt."
        }

        return nil
    }

    var newDocumentExtractedTextHint: String {
        "Importierter oder eingefuegter OCR-Text wird nach dem Speichern fuer erkannte Reisedaten und Stop-Vorschlaege genutzt."
    }

    var hasNewDocumentExtractedText: Bool {
        newDocumentExtractedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    }

    var canReviewNewDocumentStopSuggestion: Bool {
        travelDocumentParserService.parse(newDocumentExtractedText).scheduledDate != nil
    }

    private let tripService: TripService
    private let stopService: StopService
    private let travelDocumentService: TravelDocumentService
    private let travelDocumentParserService: TravelDocumentParserService
    private let travelDocumentOCRService: any TravelDocumentTextRecognizing
    private let timelineService: TimelineService
    private let mapService: MapService
    private let geocodingService: any LocationGeocoding
    private let planningStatusService: TripPlanningStatusService

    init(
        trip: Trip,
        tripService: TripService = TripService(),
        stopService: StopService = StopService(),
        travelDocumentService: TravelDocumentService = TravelDocumentService(),
        travelDocumentParserService: TravelDocumentParserService = TravelDocumentParserService(),
        travelDocumentOCRService: any TravelDocumentTextRecognizing = TravelDocumentOCRService(),
        timelineService: TimelineService = TimelineService(),
        mapService: MapService = MapService(),
        geocodingService: any LocationGeocoding = LocationGeocodingService(),
        planningStatusService: TripPlanningStatusService = TripPlanningStatusService()
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
        self.travelDocumentOCRService = travelDocumentOCRService
        self.timelineService = timelineService
        self.mapService = mapService
        self.geocodingService = geocodingService
        self.planningStatusService = planningStatusService
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
        errorMessage = nil

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

    func planningSummary(for trip: Trip) -> TripPlanningSummary {
        planningStatusService.summary(for: trip)
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
            details.append(DateDisplayFormatter.dateTime(scheduledDate))
        }

        return details.isEmpty ? nil : details.joined(separator: " - ")
    }

    func timelineDayTitle(for day: TimelineDay) -> String {
        DateDisplayFormatter.weekdayDate(day.date)
    }

    func timelineTimeTitle(for stop: Stop) -> String? {
        guard let scheduledDate = stop.scheduledDate else {
            return nil
        }

        return DateDisplayFormatter.time(scheduledDate)
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
        let parseResult = travelDocumentParserService.parse(document.extractedText)
        let details = Self.documentBaseSubtitleParts(for: document)
            + Self.documentParsedSubtitleParts(from: parseResult)
            + [Self.ocrStatusText(for: document)]

        return details.isEmpty ? nil : details.joined(separator: " - ")
    }

    func documentListDetailText(for document: TravelDocument) -> String? {
        let parseResult = travelDocumentParserService.parse(document.extractedText)
        let details = Self.documentListDetailParts(for: document, parseResult: parseResult)

        return details.isEmpty ? nil : details.joined(separator: " - ")
    }

    func documentMetadataBadges(for document: TravelDocument) -> [DocumentMetadataBadge] {
        let parseResult = travelDocumentParserService.parse(document.extractedText)
        var badges: [DocumentMetadataBadge] = []

        if document.documentType.isEmpty == false {
            badges.append(
                DocumentMetadataBadge(
                    title: document.documentType,
                    systemImage: "doc.text",
                    isHighlighted: false
                )
            )
        }

        if let parsedDateText = Self.parsedDateText(from: parseResult) {
            badges.append(
                DocumentMetadataBadge(
                    title: parsedDateText,
                    systemImage: "calendar",
                    isHighlighted: true
                )
            )
        }

        let hasExtractedText = document.extractedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false

        badges.append(
            DocumentMetadataBadge(
                title: Self.ocrStatusText(for: document),
                systemImage: hasExtractedText ? "text.viewfinder" : "doc.badge.ellipsis",
                isHighlighted: hasExtractedText
            )
        )

        return badges
    }

    func newDocumentRecognitionSummaryItems(
        calendar: Calendar = .current
    ) -> [TravelDocumentRecognitionSummaryItem] {
        let result = travelDocumentParserService.parse(
            newDocumentExtractedText,
            calendar: calendar
        )
        var items: [TravelDocumentRecognitionSummaryItem] = []

        if let suggestedStopTitle = result.suggestedStopTitle {
            items.append(
                TravelDocumentRecognitionSummaryItem(
                    id: "stopTitle",
                    title: "Stop",
                    value: suggestedStopTitle,
                    systemImage: "mappin.and.ellipse"
                )
            )
        }

        if let scheduledDate = result.scheduledDate {
            items.append(
                TravelDocumentRecognitionSummaryItem(
                    id: "schedule",
                    title: "Zeitpunkt",
                    value: DateDisplayFormatter.dateTime(scheduledDate, calendar: calendar),
                    systemImage: "calendar"
                )
            )
        }

        if let suggestedLocationName = result.suggestedLocationName {
            items.append(
                TravelDocumentRecognitionSummaryItem(
                    id: "location",
                    title: "Ort",
                    value: suggestedLocationName,
                    systemImage: "location"
                )
            )
        }

        let references = [
            result.flightNumber.map { "Flug \($0)" },
            result.trainNumber.map { "Zug \($0)" },
            result.reservationNumber.map { "Ref \($0)" },
        ].compactMap { $0 }

        if references.isEmpty == false {
            items.append(
                TravelDocumentRecognitionSummaryItem(
                    id: "reference",
                    title: "Referenz",
                    value: references.joined(separator: " - "),
                    systemImage: "number"
                )
            )
        }

        return items
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
        stopSuggestionTrainNumber = ""
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
        stopSuggestionTrainNumber = parseResult.trainNumber ?? ""
        stopSuggestionReservationNumber = parseResult.reservationNumber ?? ""

        if let scheduledDate = parseResult.scheduledDate {
            newStopScheduledDate = scheduledDate
            newStopHasScheduledDate = true
        }
    }

    func cancelCreateStop() {
        newStopTitle = ""
        newStopLocationName = ""
        newStopLatitudeText = ""
        newStopLongitudeText = ""
        newStopScheduledDate = nil
        newStopHasScheduledDate = false
        stopErrorMessage = nil
        isResolvingNewStopCoordinates = false
        isShowingCreateStop = false
        isReviewingDocumentStopSuggestion = false
        stopSuggestionDocumentType = ""
        stopSuggestionTextExcerpt = ""
        stopSuggestionFlightNumber = ""
        stopSuggestionTrainNumber = ""
        stopSuggestionReservationNumber = ""
    }

    func showCreateDocument() {
        newDocumentTitle = ""
        newDocumentType = ""
        newDocumentFileName = ""
        newDocumentExtractedText = ""
        documentErrorMessage = nil
        documentImportSuccessMessage = nil
        isShowingDocumentImporter = false
        isShowingDocumentScanner = false
        isImportingDocument = false
        pendingDocumentStopSuggestion = nil
        isShowingCreateDocument = true
    }

    func cancelCreateDocument() {
        newDocumentTitle = ""
        newDocumentType = ""
        newDocumentFileName = ""
        newDocumentExtractedText = ""
        documentErrorMessage = nil
        documentImportSuccessMessage = nil
        isShowingDocumentImporter = false
        isShowingDocumentScanner = false
        isImportingDocument = false
        pendingDocumentStopSuggestion = nil
        isShowingCreateDocument = false
    }

    func showDocumentImporter() {
        documentErrorMessage = nil
        documentImportSuccessMessage = nil
        isShowingDocumentImporter = true
    }

    func showDocumentScanner() {
        documentErrorMessage = nil
        documentImportSuccessMessage = nil
        isShowingDocumentScanner = true
    }

    func cancelDocumentScanner() {
        isShowingDocumentScanner = false
    }

    func failDocumentScanner() {
        isShowingDocumentScanner = false
        documentImportSuccessMessage = nil
        documentErrorMessage = "Das Dokument konnte nicht gescannt werden."
    }

    func importScannedDocumentPages(_ pages: [Data]) async {
        isShowingDocumentScanner = false
        documentErrorMessage = nil
        documentImportSuccessMessage = nil

        guard pages.isEmpty == false else {
            documentErrorMessage = "Der Scan enthaelt keine Seiten."
            return
        }

        isImportingDocument = true
        defer { isImportingDocument = false }

        do {
            let recognizedText = try await travelDocumentOCRService.recognizeText(inImageData: pages)
            newDocumentFileName = ""
            newDocumentExtractedText = recognizedText

            if newDocumentTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                newDocumentTitle = "Dokumentenscan"
            }

            documentImportSuccessMessage = pages.count == 1
                ? "Eine gescannte Seite wurde erkannt und kann geprueft werden."
                : "\(pages.count) gescannte Seiten wurden erkannt und koennen geprueft werden."
        } catch TravelDocumentOCRError.unreadableImage {
            documentErrorMessage = "Mindestens eine gescannte Seite konnte nicht gelesen werden."
        } catch TravelDocumentOCRError.noRecognizedText {
            documentErrorMessage = "Im gescannten Dokument wurde kein Text erkannt."
        } catch {
            documentErrorMessage = "Die Texterkennung des Scans ist fehlgeschlagen."
        }
    }

    func importDocumentFile(from result: Result<[URL], Error>) async {
        documentErrorMessage = nil
        documentImportSuccessMessage = nil

        let urls: [URL]

        switch result {
        case let .success(selectedURLs):
            urls = selectedURLs
        case let .failure(error):
            if (error as? CocoaError)?.code != .userCancelled {
                documentErrorMessage = "Die Datei konnte nicht importiert werden."
            }
            return
        }

        guard let url = urls.first else {
            documentErrorMessage = "Es wurde keine Datei ausgewaehlt."
            return
        }

        isImportingDocument = true
        defer { isImportingDocument = false }

        do {
            let recognizedText = try await travelDocumentOCRService.recognizeText(inDocumentAt: url)
            newDocumentFileName = url.lastPathComponent
            newDocumentExtractedText = recognizedText

            if newDocumentTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                newDocumentTitle = url.deletingPathExtension().lastPathComponent
            }

            documentImportSuccessMessage = "Text wurde erkannt und kann vor dem Speichern geprueft werden."
        } catch TravelDocumentOCRError.unreadableImage {
            documentErrorMessage = "Die ausgewaehlte Bilddatei konnte nicht gelesen werden."
        } catch TravelDocumentOCRError.unreadablePDF {
            documentErrorMessage = "Die ausgewaehlte PDF-Datei konnte nicht gelesen werden."
        } catch TravelDocumentOCRError.noRecognizedText {
            documentErrorMessage = "In der ausgewaehlten Datei wurde kein Text erkannt."
        } catch {
            documentErrorMessage = "Die Texterkennung ist fehlgeschlagen."
        }
    }

    func applyNewDocumentTypeSuggestion(_ suggestion: String) {
        newDocumentType = suggestion
    }

    func setNewStopScheduledDateEnabled(_ isEnabled: Bool) {
        newStopHasScheduledDate = isEnabled
        newStopScheduledDate = isEnabled ? (newStopScheduledDate ?? startDate ?? Date()) : nil
    }

    func createStop(for trip: Trip, in modelContext: ModelContext) {
        stopErrorMessage = nil

        do {
            guard isReviewingDocumentStopSuggestion == false || (newStopHasScheduledDate && newStopScheduledDate != nil) else {
                stopErrorMessage = "Bitte waehle ein Datum und eine Uhrzeit fuer den vorgeschlagenen Stop aus."
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
            stopSuccessMessage = isReviewingDocumentStopSuggestion
                ? "Stop \"\(stop.title)\" wurde aus der Reiseunterlage erstellt."
                : "Stop \"\(stop.title)\" wurde erstellt."
            isShowingCreateStop = false
            isReviewingDocumentStopSuggestion = false
            stopSuggestionDocumentType = ""
            stopSuggestionTextExcerpt = ""
            stopSuggestionFlightNumber = ""
            stopSuggestionTrainNumber = ""
            stopSuggestionReservationNumber = ""
        } catch StopValidationError.emptyTitle {
            stopErrorMessage = isReviewingDocumentStopSuggestion
                ? "Bitte gib einen Namen fuer den vorgeschlagenen Stop ein."
                : "Bitte gib einen Namen fuer den Stop ein."
        } catch StopValidationError.invalidCoordinates {
            stopErrorMessage = "Bitte gib gueltige Koordinaten ein."
        } catch {
            stopErrorMessage = "Der Stop konnte nicht erstellt werden."
        }
    }

    func createDocument(
        for trip: Trip,
        in modelContext: ModelContext,
        reviewStopSuggestion: Bool = false
    ) {
        documentErrorMessage = nil
        pendingDocumentStopSuggestion = nil

        do {
            let document = try travelDocumentService.createDocument(
                title: newDocumentTitle,
                documentType: newDocumentType,
                fileName: newDocumentFileName,
                extractedText: newDocumentExtractedText,
                for: trip
            )
            modelContext.insert(document)
            pendingDocumentStopSuggestion = reviewStopSuggestion ? document : nil
            newDocumentTitle = ""
            newDocumentType = ""
            newDocumentFileName = ""
            newDocumentExtractedText = ""
            documentErrorMessage = nil
            documentImportSuccessMessage = nil
            isShowingDocumentImporter = false
            isShowingDocumentScanner = false
            isImportingDocument = false
            isShowingCreateDocument = false
        } catch TravelDocumentValidationError.emptyTitle {
            documentErrorMessage = "Bitte gib einen Namen fuer die Reiseunterlage ein."
        } catch {
            documentErrorMessage = "Die Reiseunterlage konnte nicht erstellt werden."
        }
    }

    func showPendingDocumentStopSuggestion() {
        guard let document = pendingDocumentStopSuggestion else {
            return
        }

        pendingDocumentStopSuggestion = nil
        showCreateStop(from: document)
    }

    func fillNewStopCoordinatesFromLocationName() async {
        stopErrorMessage = nil
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

    private static func documentBaseSubtitleParts(for document: TravelDocument) -> [String] {
        [
            document.documentType,
            document.fileName
        ].filter { $0.isEmpty == false }
    }

    private static func documentParsedSubtitleParts(from parseResult: TravelDocumentParseResult) -> [String] {
        var details = documentReferenceSubtitleParts(from: parseResult)

        if let parsedDateText = parsedDateText(from: parseResult) {
            details.append(parsedDateText)
        }

        return details
    }

    private static func documentListDetailParts(
        for document: TravelDocument,
        parseResult: TravelDocumentParseResult
    ) -> [String] {
        [
            document.fileName
        ].filter { $0.isEmpty == false } + documentReferenceSubtitleParts(from: parseResult)
    }

    private static func documentReferenceSubtitleParts(from parseResult: TravelDocumentParseResult) -> [String] {
        var details: [String] = []

        if let flightNumber = parseResult.flightNumber {
            details.append("Flug \(flightNumber)")
        }

        if let trainNumber = parseResult.trainNumber {
            details.append("Zug \(trainNumber)")
        }

        if let reservationNumber = parseResult.reservationNumber {
            details.append("Ref \(reservationNumber)")
        }

        if let suggestedLocationName = parseResult.suggestedLocationName {
            details.append("Ort \(suggestedLocationName)")
        }

        return details
    }

    private static func ocrStatusText(for document: TravelDocument) -> String {
        let hasExtractedText = document.extractedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false

        return hasExtractedText ? "OCR vorhanden" : "OCR offen"
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
