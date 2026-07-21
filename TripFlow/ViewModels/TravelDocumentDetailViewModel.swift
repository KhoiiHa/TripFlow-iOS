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
    var isShowingSourcePreview = false
    var sourcePreviewURL: URL?
    var sourcePreviewErrorMessage: String?
    var isShowingSourceShare = false
    var sourceShareURL: URL?
    var sourceShareErrorMessage: String?
    var isShowingSourceReplacementImporter = false
    var isShowingSourceReplacementScanner = false
    var isShowingSourceReplacementReview = false
    var isPreparingSourceReplacement = false
    var sourceReplacementFileName = ""
    var sourceReplacementExtractedText = ""
    var sourceReplacementErrorMessage: String?
    var sourceReplacementSuccessMessage: String?
    let hasSourceDocument: Bool

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

    var canConfirmSourceReplacement: Bool {
        pendingSourceReplacementData != nil
            && pendingSourceReplacementFingerprint != nil
            && sourceReplacementFileName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    }

    private let travelDocumentService: TravelDocumentService
    private let travelDocumentParserService: TravelDocumentParserService
    private let stopService: StopService
    private let travelDocumentSourcePreviewService: any TravelDocumentSourcePreviewing
    private let travelDocumentOCRService: any TravelDocumentTextRecognizing
    private let travelDocumentSourceService: any TravelDocumentSourcePreparing
    private var pendingSourceReplacementData: Data?
    private var pendingSourceReplacementFingerprint: String?

    init(
        document: TravelDocument,
        travelDocumentService: TravelDocumentService = TravelDocumentService(),
        travelDocumentParserService: TravelDocumentParserService = TravelDocumentParserService(),
        stopService: StopService = StopService(),
        travelDocumentSourcePreviewService: any TravelDocumentSourcePreviewing = TravelDocumentSourceService(),
        travelDocumentOCRService: any TravelDocumentTextRecognizing = TravelDocumentOCRService(),
        travelDocumentSourceService: any TravelDocumentSourcePreparing = TravelDocumentSourceService()
    ) {
        title = document.title
        documentType = document.documentType
        fileName = document.fileName
        extractedText = document.extractedText
        hasSourceDocument = document.sourceData != nil
        self.travelDocumentService = travelDocumentService
        self.travelDocumentParserService = travelDocumentParserService
        self.stopService = stopService
        self.travelDocumentSourcePreviewService = travelDocumentSourcePreviewService
        self.travelDocumentOCRService = travelDocumentOCRService
        self.travelDocumentSourceService = travelDocumentSourceService
    }

    func showSourcePreview(for document: TravelDocument) {
        sourcePreviewErrorMessage = nil

        guard let sourceData = document.sourceData else {
            sourcePreviewErrorMessage = "Fuer diese Reiseunterlage ist keine Originaldatei gespeichert."
            return
        }

        do {
            sourcePreviewURL = try travelDocumentSourcePreviewService.temporaryPreviewURL(
                for: sourceData,
                fileName: document.fileName
            )
            isShowingSourcePreview = true
        } catch {
            sourcePreviewURL = nil
            isShowingSourcePreview = false
            sourcePreviewErrorMessage = "Die Originaldatei konnte nicht angezeigt werden."
        }
    }

    func dismissSourcePreview() {
        if let sourcePreviewURL {
            travelDocumentSourcePreviewService.removeTemporaryPreview(at: sourcePreviewURL)
        }

        sourcePreviewURL = nil
        isShowingSourcePreview = false
    }

    func showSourceShare(for document: TravelDocument) {
        sourceShareErrorMessage = nil

        guard let sourceData = document.sourceData else {
            sourceShareErrorMessage = "Fuer diese Reiseunterlage ist keine Originaldatei gespeichert."
            return
        }

        do {
            sourceShareURL = try travelDocumentSourcePreviewService.temporaryExportURL(
                for: sourceData,
                fileName: document.fileName
            )
            isShowingSourceShare = true
        } catch {
            sourceShareURL = nil
            isShowingSourceShare = false
            sourceShareErrorMessage = "Die Originaldatei konnte nicht zum Teilen vorbereitet werden."
        }
    }

    func dismissSourceShare() {
        if let sourceShareURL {
            travelDocumentSourcePreviewService.removeTemporaryExport(at: sourceShareURL)
        }

        sourceShareURL = nil
        isShowingSourceShare = false
    }

    func showSourceReplacementImporter() {
        sourceReplacementErrorMessage = nil
        sourceReplacementSuccessMessage = nil
        isShowingSourceReplacementImporter = true
    }

    func showSourceReplacementScanner() {
        sourceReplacementErrorMessage = nil
        sourceReplacementSuccessMessage = nil
        isShowingSourceReplacementScanner = true
    }

    func cancelSourceReplacementScanner() {
        isShowingSourceReplacementScanner = false
    }

    func failSourceReplacementScanner() {
        isShowingSourceReplacementScanner = false
        sourceReplacementErrorMessage = "Das Ersatzdokument konnte nicht gescannt werden."
    }

    func importSourceReplacement(from result: Result<[URL], Error>) async {
        sourceReplacementErrorMessage = nil

        let urls: [URL]

        switch result {
        case let .success(selectedURLs):
            urls = selectedURLs
        case let .failure(error):
            if (error as? CocoaError)?.code != .userCancelled {
                sourceReplacementErrorMessage = "Die Ersatzdatei konnte nicht importiert werden."
            }
            return
        }

        guard let url = urls.first else {
            sourceReplacementErrorMessage = "Es wurde keine Ersatzdatei ausgewaehlt."
            return
        }

        isPreparingSourceReplacement = true
        defer { isPreparingSourceReplacement = false }

        do {
            try travelDocumentSourceService.validateDocument(at: url)
            let recognizedText = try await travelDocumentOCRService.recognizeText(inDocumentAt: url)
            let sourceData = try travelDocumentSourceService.data(from: url)
            prepareSourceReplacement(
                fileName: url.lastPathComponent,
                extractedText: recognizedText,
                sourceData: sourceData
            )
        } catch TravelDocumentOCRError.unreadableImage {
            sourceReplacementErrorMessage = "Die ausgewaehlte Bilddatei konnte nicht gelesen werden."
        } catch TravelDocumentOCRError.unreadablePDF {
            sourceReplacementErrorMessage = "Die ausgewaehlte PDF-Datei konnte nicht gelesen werden."
        } catch TravelDocumentOCRError.noRecognizedText {
            sourceReplacementErrorMessage = "In der ausgewaehlten Datei wurde kein Text erkannt."
        } catch TravelDocumentSourceError.unreadableFile {
            sourceReplacementErrorMessage = "Die ausgewaehlte Datei konnte nicht lokal vorbereitet werden."
        } catch TravelDocumentSourceError.sourceTooLarge(let maximumByteCount) {
            sourceReplacementErrorMessage = "Die Ersatzdatei darf hoechstens \(Self.megabytes(maximumByteCount)) MB gross sein."
        } catch {
            sourceReplacementErrorMessage = "Die Texterkennung der Ersatzdatei ist fehlgeschlagen."
        }
    }

    func importScannedSourceReplacementPages(_ pages: [Data]) async {
        isShowingSourceReplacementScanner = false
        sourceReplacementErrorMessage = nil

        guard pages.isEmpty == false else {
            sourceReplacementErrorMessage = "Der Ersatzscan enthaelt keine Seiten."
            return
        }

        isPreparingSourceReplacement = true
        defer { isPreparingSourceReplacement = false }

        do {
            try travelDocumentSourceService.validateScannedPages(pages)
            let recognizedText = try await travelDocumentOCRService.recognizeText(inImageData: pages)
            let sourceData = try travelDocumentSourceService.pdfData(fromScannedPages: pages)
            prepareSourceReplacement(
                fileName: "Dokumentenscan.pdf",
                extractedText: recognizedText,
                sourceData: sourceData
            )
        } catch TravelDocumentOCRError.unreadableImage {
            sourceReplacementErrorMessage = "Mindestens eine gescannte Seite konnte nicht gelesen werden."
        } catch TravelDocumentOCRError.noRecognizedText {
            sourceReplacementErrorMessage = "Im Ersatzscan wurde kein Text erkannt."
        } catch TravelDocumentSourceError.unreadableScanPage {
            sourceReplacementErrorMessage = "Mindestens eine gescannte Seite konnte nicht vorbereitet werden."
        } catch TravelDocumentSourceError.tooManyScanPages(let maximumPageCount) {
            sourceReplacementErrorMessage = "Ein Ersatzscan darf hoechstens \(maximumPageCount) Seiten enthalten."
        } catch TravelDocumentSourceError.sourceTooLarge(let maximumByteCount) {
            sourceReplacementErrorMessage = "Der Ersatzscan darf hoechstens \(Self.megabytes(maximumByteCount)) MB gross sein."
        } catch {
            sourceReplacementErrorMessage = "Die Texterkennung des Ersatzscans ist fehlgeschlagen."
        }
    }

    func cancelSourceReplacementReview() {
        clearSourceReplacementDraft()
        sourceReplacementErrorMessage = nil
        isShowingSourceReplacementReview = false
    }

    func confirmSourceReplacement(for document: TravelDocument) {
        guard let sourceData = pendingSourceReplacementData,
              let sourceFingerprint = pendingSourceReplacementFingerprint else {
            sourceReplacementErrorMessage = "Die Ersatzdatei ist nicht mehr verfuegbar."
            return
        }

        do {
            try travelDocumentService.replaceSource(
                of: document,
                fileName: sourceReplacementFileName,
                extractedText: sourceReplacementExtractedText,
                sourceData: sourceData,
                sourceFingerprint: sourceFingerprint
            )
            fileName = document.fileName
            extractedText = document.extractedText
            clearSourceReplacementDraft()
            sourceReplacementErrorMessage = nil
            sourceReplacementSuccessMessage = "Die Originaldatei wurde ersetzt."
            isShowingSourceReplacementReview = false
        } catch TravelDocumentValidationError.duplicateSource {
            sourceReplacementErrorMessage = "Diese Originaldatei ist in diesem Trip bereits gespeichert."
        } catch {
            sourceReplacementErrorMessage = "Die Originaldatei konnte nicht ersetzt werden."
        }
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

        if result.departureScheduledDate == nil,
           result.arrivalScheduledDate == nil,
           let scheduledDate = result.scheduledDate {
            items.append(
                TravelDocumentRecognitionSummaryItem(
                    id: "schedule",
                    title: "Zeitpunkt",
                    value: scheduleText(for: scheduledDate, calendar: calendar),
                    systemImage: "calendar"
                )
            )
        }

        if let departureLocationName = result.departureLocationName {
            items.append(
                TravelDocumentRecognitionSummaryItem(
                    id: "departure",
                    title: "Abfahrt",
                    value: departureLocationName,
                    systemImage: "arrow.up.right.circle"
                )
            )
        }

        if let departureScheduledDate = result.departureScheduledDate {
            items.append(
                TravelDocumentRecognitionSummaryItem(
                    id: "departureSchedule",
                    title: "Abfahrtszeit",
                    value: scheduleText(for: departureScheduledDate, calendar: calendar),
                    systemImage: "clock.arrow.circlepath"
                )
            )
        }

        if let arrivalLocationName = result.arrivalLocationName {
            items.append(
                TravelDocumentRecognitionSummaryItem(
                    id: "arrival",
                    title: "Ankunft",
                    value: arrivalLocationName,
                    systemImage: "arrow.down.right.circle"
                )
            )
        }

        if let arrivalScheduledDate = result.arrivalScheduledDate {
            items.append(
                TravelDocumentRecognitionSummaryItem(
                    id: "arrivalSchedule",
                    title: "Ankunftszeit",
                    value: scheduleText(for: arrivalScheduledDate, calendar: calendar),
                    systemImage: "clock.badge.checkmark"
                )
            )
        }

        if result.departureLocationName == nil,
           result.arrivalLocationName == nil,
           let suggestedLocationName = result.suggestedLocationName {
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

    func parsedDepartureScheduleText(calendar: Calendar = .current) -> String? {
        guard let scheduledDate = parsedTravelDocumentResult(calendar: calendar).departureScheduledDate else {
            return nil
        }

        return scheduleText(for: scheduledDate, calendar: calendar)
    }

    func parsedArrivalScheduleText(calendar: Calendar = .current) -> String? {
        guard let scheduledDate = parsedTravelDocumentResult(calendar: calendar).arrivalScheduledDate else {
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

    func parsedDepartureLocationName(calendar: Calendar = .current) -> String? {
        parsedTravelDocumentResult(calendar: calendar).departureLocationName
    }

    func parsedArrivalLocationName(calendar: Calendar = .current) -> String? {
        parsedTravelDocumentResult(calendar: calendar).arrivalLocationName
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

        let result = parsedTravelDocumentResult(calendar: calendar)

        guard result.scheduledDate == nil else {
            return nil
        }

        if result.departureLocationName != nil,
           result.arrivalLocationName != nil,
           result.arrivalScheduledDate == nil {
            return "Kein Stop-Vorschlag: Fuer das erkannte Ziel fehlt noch eine Ankunftszeit."
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

    private func prepareSourceReplacement(
        fileName: String,
        extractedText: String,
        sourceData: Data
    ) {
        sourceReplacementFileName = fileName
        sourceReplacementExtractedText = extractedText
        pendingSourceReplacementData = sourceData
        pendingSourceReplacementFingerprint = travelDocumentSourceService.fingerprint(for: sourceData)
        sourceReplacementErrorMessage = nil
        isShowingSourceReplacementReview = true
    }

    private func clearSourceReplacementDraft() {
        sourceReplacementFileName = ""
        sourceReplacementExtractedText = ""
        pendingSourceReplacementData = nil
        pendingSourceReplacementFingerprint = nil
    }

    private static func megabytes(_ byteCount: Int) -> Int {
        max(1, byteCount / 1_024 / 1_024)
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
