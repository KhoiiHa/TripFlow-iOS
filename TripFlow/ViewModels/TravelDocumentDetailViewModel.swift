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

    init(
        document: TravelDocument,
        travelDocumentService: TravelDocumentService = TravelDocumentService()
    ) {
        title = document.title
        documentType = document.documentType
        fileName = document.fileName
        extractedText = document.extractedText
        self.travelDocumentService = travelDocumentService
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
