//
//  TravelDocumentDetailViewModel.swift
//  TripFlow
//
//  Created by Vu Minh Khoi Ha on 07.07.26.
//

import Foundation
import SwiftData

struct TravelDocumentRecognitionSummaryItem: Equatable, Identifiable {
    let id: String
    let title: String
    let value: String
    let systemImage: String
}

@Observable
final class TravelDocumentDetailViewModel {
    var title: String
    var documentType: String
    var fileName: String
    var extractedText: String
    var errorMessage: String?
    var isShowingStopSuggestion = false
    var stopSuggestionTitle = ""
    var stopSuggestionLocationName = ""
    var stopSuggestionScheduledDate: Date?
    var stopSuggestionDocumentType = ""
    var stopSuggestionTextExcerpt = ""
    var stopSuggestionFlightNumber = ""
    var stopSuggestionTrainNumber = ""
    var stopSuggestionReservationNumber = ""
    var stopSuggestionErrorMessage: String?
    var stopSuggestionSuccessMessage: String?

    var canSave: Bool {
        saveDisabledReason == nil
    }

    var saveDisabledReason: String? {
        if title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Name fuer die Reiseunterlage fehlt."
        }

        return nil
    }

    var canCreateStopSuggestion: Bool {
        createStopSuggestionDisabledReason == nil
    }

    var createStopSuggestionDisabledReason: String? {
        if stopSuggestionTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Name fuer den vorgeschlagenen Stop fehlt."
        }

        if stopSuggestionScheduledDate == nil {
            return "Datum und Uhrzeit fuer den vorgeschlagenen Stop fehlen."
        }

        return nil
    }

    var hasExtractedText: Bool {
        extractedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    }

    private let travelDocumentService: TravelDocumentService
    private let travelDocumentParserService: TravelDocumentParserService
    private let stopService: StopService

    init(
        document: TravelDocument,
        travelDocumentService: TravelDocumentService = TravelDocumentService(),
        travelDocumentParserService: TravelDocumentParserService = TravelDocumentParserService(),
        stopService: StopService = StopService()
    ) {
        title = document.title
        documentType = document.documentType
        fileName = document.fileName
        extractedText = document.extractedText
        self.travelDocumentService = travelDocumentService
        self.travelDocumentParserService = travelDocumentParserService
        self.stopService = stopService
    }

    func parsedTravelDocumentResult(calendar: Calendar = .current) -> TravelDocumentParseResult {
        travelDocumentParserService.parse(extractedText, calendar: calendar)
    }

    func recognitionSummaryItems(calendar: Calendar = .current) -> [TravelDocumentRecognitionSummaryItem] {
        let result = parsedTravelDocumentResult(calendar: calendar)
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
                    value: scheduleText(for: scheduledDate, calendar: calendar),
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

        if let referenceText = Self.referenceText(from: result) {
            items.append(
                TravelDocumentRecognitionSummaryItem(
                    id: "reference",
                    title: "Referenz",
                    value: referenceText,
                    systemImage: "number"
                )
            )
        }

        return items
    }

    func hasParsedTravelData(calendar: Calendar = .current) -> Bool {
        let result = parsedTravelDocumentResult(calendar: calendar)

        return result.scheduledDate != nil
            || result.suggestedStopTitle != nil
            || result.suggestedLocationName != nil
            || result.flightNumber != nil
            || result.trainNumber != nil
            || result.reservationNumber != nil
    }

    func parsedScheduleText(calendar: Calendar = .current) -> String? {
        guard let scheduledDate = parsedTravelDocumentResult(calendar: calendar).scheduledDate else {
            return nil
        }

        return scheduleText(for: scheduledDate, calendar: calendar)
    }

    private func scheduleText(for scheduledDate: Date, calendar: Calendar) -> String {
        DateDisplayFormatter.dateTime(scheduledDate, calendar: calendar)
    }

    func parsedSuggestedStopTitle(calendar: Calendar = .current) -> String? {
        parsedTravelDocumentResult(calendar: calendar).suggestedStopTitle
    }

    func parsedSuggestedLocationName(calendar: Calendar = .current) -> String? {
        parsedTravelDocumentResult(calendar: calendar).suggestedLocationName
    }

    func parsedFlightNumber(calendar: Calendar = .current) -> String? {
        parsedTravelDocumentResult(calendar: calendar).flightNumber
    }

    func parsedTrainNumber(calendar: Calendar = .current) -> String? {
        parsedTravelDocumentResult(calendar: calendar).trainNumber
    }

    func parsedReservationNumber(calendar: Calendar = .current) -> String? {
        parsedTravelDocumentResult(calendar: calendar).reservationNumber
    }

    func canShowStopSuggestionAction(for document: TravelDocument, calendar: Calendar = .current) -> Bool {
        document.trip != nil && parsedTravelDocumentResult(calendar: calendar).scheduledDate != nil
    }

    func stopSuggestionUnavailableMessage(for document: TravelDocument, calendar: Calendar = .current) -> String? {
        guard document.trip != nil, hasExtractedText else {
            return nil
        }

        guard parsedTravelDocumentResult(calendar: calendar).scheduledDate == nil else {
            return nil
        }

        return "Kein Stop-Vorschlag: Im OCR-Text wurde noch kein Datum erkannt."
    }

    func showStopSuggestion(from document: TravelDocument, calendar: Calendar = .current) {
        let result = parsedTravelDocumentResult(calendar: calendar)

        stopSuggestionTitle = result.suggestedStopTitle ?? title
        stopSuggestionLocationName = result.suggestedLocationName ?? ""
        stopSuggestionScheduledDate = result.scheduledDate
        stopSuggestionDocumentType = document.documentType
        stopSuggestionTextExcerpt = Self.textExcerpt(from: document.extractedText)
        stopSuggestionFlightNumber = result.flightNumber ?? ""
        stopSuggestionTrainNumber = result.trainNumber ?? ""
        stopSuggestionReservationNumber = result.reservationNumber ?? ""
        stopSuggestionErrorMessage = nil
        stopSuggestionSuccessMessage = nil
        isShowingStopSuggestion = true
    }

    func cancelStopSuggestionReview() {
        stopSuggestionTitle = ""
        stopSuggestionLocationName = ""
        stopSuggestionScheduledDate = nil
        stopSuggestionDocumentType = ""
        stopSuggestionTextExcerpt = ""
        stopSuggestionFlightNumber = ""
        stopSuggestionTrainNumber = ""
        stopSuggestionReservationNumber = ""
        stopSuggestionErrorMessage = nil
        isShowingStopSuggestion = false
    }

    func createStopSuggestion(from document: TravelDocument, in modelContext: ModelContext) {
        guard let trip = document.trip else {
            stopSuggestionErrorMessage = "Der Stop konnte keinem Trip zugeordnet werden."
            return
        }

        guard let scheduledDate = stopSuggestionScheduledDate else {
            stopSuggestionErrorMessage = "Bitte waehle ein Datum und eine Uhrzeit fuer den vorgeschlagenen Stop aus."
            return
        }

        do {
            let stop = try stopService.createStop(
                title: stopSuggestionTitle,
                locationName: stopSuggestionLocationName,
                scheduledDate: scheduledDate,
                for: trip
            )
            modelContext.insert(stop)
            stopSuggestionTitle = ""
            stopSuggestionLocationName = ""
            stopSuggestionScheduledDate = nil
            stopSuggestionDocumentType = ""
            stopSuggestionTextExcerpt = ""
            stopSuggestionFlightNumber = ""
            stopSuggestionTrainNumber = ""
            stopSuggestionReservationNumber = ""
            stopSuggestionErrorMessage = nil
            stopSuggestionSuccessMessage = "Stop \"\(stop.title)\" wurde aus der Reiseunterlage erstellt."
            isShowingStopSuggestion = false
        } catch StopValidationError.emptyTitle {
            stopSuggestionErrorMessage = "Bitte gib einen Namen fuer den vorgeschlagenen Stop ein."
        } catch {
            stopSuggestionErrorMessage = "Der Stop konnte nicht erstellt werden."
        }
    }

    func save(document: TravelDocument) {
        errorMessage = nil

        do {
            try travelDocumentService.updateDocument(
                document,
                title: title,
                documentType: documentType,
                fileName: fileName,
                extractedText: extractedText
            )
            errorMessage = nil
        } catch TravelDocumentValidationError.emptyTitle {
            errorMessage = "Bitte gib einen Namen fuer die Reiseunterlage ein."
        } catch {
            errorMessage = "Die Reiseunterlage konnte nicht gespeichert werden."
        }
    }

    private static func textExcerpt(from text: String) -> String {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)

        guard trimmedText.count > 120 else {
            return trimmedText
        }

        return String(trimmedText.prefix(120)) + "..."
    }

    private static func referenceText(from result: TravelDocumentParseResult) -> String? {
        let references = [
            result.flightNumber.map { "Flug \($0)" },
            result.trainNumber.map { "Zug \($0)" },
            result.reservationNumber.map { "Ref \($0)" }
        ].compactMap { $0 }

        guard references.isEmpty == false else {
            return nil
        }

        return references.joined(separator: " - ")
    }
}
