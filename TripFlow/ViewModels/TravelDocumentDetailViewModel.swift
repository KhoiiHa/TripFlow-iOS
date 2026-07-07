//
//  TravelDocumentDetailViewModel.swift
//  TripFlow
//
//  Created by Vu Minh Khoi Ha on 07.07.26.
//

import Foundation

@Observable
final class TravelDocumentDetailViewModel {
    var title: String
    var documentType: String
    var fileName: String
    var extractedText: String
    var errorMessage: String?

    var canSave: Bool {
        title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    }

    private let travelDocumentService: TravelDocumentService
    private let travelDocumentParserService: TravelDocumentParserService

    init(
        document: TravelDocument,
        travelDocumentService: TravelDocumentService = TravelDocumentService(),
        travelDocumentParserService: TravelDocumentParserService = TravelDocumentParserService()
    ) {
        title = document.title
        documentType = document.documentType
        fileName = document.fileName
        extractedText = document.extractedText
        self.travelDocumentService = travelDocumentService
        self.travelDocumentParserService = travelDocumentParserService
    }

    func parsedTravelDocumentResult(calendar: Calendar = .current) -> TravelDocumentParseResult {
        travelDocumentParserService.parse(extractedText, calendar: calendar)
    }

    func hasParsedTravelData(calendar: Calendar = .current) -> Bool {
        let result = parsedTravelDocumentResult(calendar: calendar)

        return result.scheduledDate != nil
            || result.suggestedStopTitle != nil
            || result.suggestedLocationName != nil
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
}
