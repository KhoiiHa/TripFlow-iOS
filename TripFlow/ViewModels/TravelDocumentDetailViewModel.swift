//
//  TravelDocumentDetailViewModel.swift
//  TripFlow
//
//  Created by Vu Minh Khoi Ha on 07.07.26.
//

import Foundation
import SwiftData

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
    var stopSuggestionReservationNumber = ""
    var stopSuggestionErrorMessage: String?
    var stopSuggestionSuccessMessage: String?

    var canSave: Bool {
        title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    }

    var canCreateStopSuggestion: Bool {
        stopSuggestionTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            && stopSuggestionScheduledDate != nil
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

    func hasParsedTravelData(calendar: Calendar = .current) -> Bool {
        let result = parsedTravelDocumentResult(calendar: calendar)

        return result.scheduledDate != nil
            || result.suggestedStopTitle != nil
            || result.suggestedLocationName != nil
            || result.flightNumber != nil
            || result.reservationNumber != nil
    }

    func parsedScheduleText(calendar: Calendar = .current) -> String? {
        guard let scheduledDate = parsedTravelDocumentResult(calendar: calendar).scheduledDate else {
            return nil
        }

        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateStyle = .medium
        formatter.timeStyle = .short

        return formatter.string(from: scheduledDate)
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

    func parsedReservationNumber(calendar: Calendar = .current) -> String? {
        parsedTravelDocumentResult(calendar: calendar).reservationNumber
    }

    func canShowStopSuggestionAction(for document: TravelDocument, calendar: Calendar = .current) -> Bool {
        document.trip != nil && parsedTravelDocumentResult(calendar: calendar).scheduledDate != nil
    }

    func showStopSuggestion(from document: TravelDocument, calendar: Calendar = .current) {
        let result = parsedTravelDocumentResult(calendar: calendar)

        stopSuggestionTitle = result.suggestedStopTitle ?? title
        stopSuggestionLocationName = result.suggestedLocationName ?? ""
        stopSuggestionScheduledDate = result.scheduledDate
        stopSuggestionDocumentType = document.documentType
        stopSuggestionTextExcerpt = Self.textExcerpt(from: document.extractedText)
        stopSuggestionFlightNumber = result.flightNumber ?? ""
        stopSuggestionReservationNumber = result.reservationNumber ?? ""
        stopSuggestionErrorMessage = nil
        stopSuggestionSuccessMessage = nil
        isShowingStopSuggestion = true
    }

    func createStopSuggestion(from document: TravelDocument, in modelContext: ModelContext) {
        guard let trip = document.trip else {
            stopSuggestionErrorMessage = "Der Stop konnte keinem Trip zugeordnet werden."
            return
        }

        guard let scheduledDate = stopSuggestionScheduledDate else {
            stopSuggestionErrorMessage = "Bitte pruefe Datum und Uhrzeit fuer den vorgeschlagenen Stop."
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
            stopSuggestionReservationNumber = ""
            stopSuggestionErrorMessage = nil
            stopSuggestionSuccessMessage = "Stop \"\(stop.title)\" wurde erstellt."
            isShowingStopSuggestion = false
        } catch StopValidationError.emptyTitle {
            stopSuggestionErrorMessage = "Bitte gib einen Namen fuer den Stop ein."
        } catch {
            stopSuggestionErrorMessage = "Der Stop konnte nicht erstellt werden."
        }
    }

    func save(document: TravelDocument) {
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
}
