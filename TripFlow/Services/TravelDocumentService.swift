//
//  TravelDocumentService.swift
//  TripFlow
//
//  Created by Vu Minh Khoi Ha on 06.07.26.
//

import Foundation

enum TravelDocumentValidationError: Error, Equatable {
    case emptyTitle
}

struct TravelDocumentService {
    func createDocument(
        title: String,
        documentType: String = "",
        fileName: String = "",
        extractedText: String = "",
        for trip: Trip
    ) throws -> TravelDocument {
        let values = try validate(title: title, documentType: documentType, fileName: fileName, extractedText: extractedText)
        let document = TravelDocument(
            title: values.title,
            documentType: values.documentType,
            fileName: values.fileName,
            extractedText: values.extractedText,
            trip: trip
        )

        trip.documents.append(document)
        trip.updatedAt = Date()

        return document
    }

    func updateDocument(
        _ document: TravelDocument,
        title: String,
        documentType: String,
        fileName: String,
        extractedText: String
    ) throws {
        let values = try validate(title: title, documentType: documentType, fileName: fileName, extractedText: extractedText)

        document.title = values.title
        document.documentType = values.documentType
        document.fileName = values.fileName
        document.extractedText = values.extractedText
        document.updatedAt = Date()
        document.trip?.updatedAt = Date()
    }

    func applyExtractedText(_ text: String, to document: TravelDocument) {
        document.extractedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        document.updatedAt = Date()
        document.trip?.updatedAt = Date()
    }

    private func validate(
        title: String,
        documentType: String,
        fileName: String,
        extractedText: String
    ) throws -> (title: String, documentType: String, fileName: String, extractedText: String) {
        let normalizedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)

        guard normalizedTitle.isEmpty == false else {
            throw TravelDocumentValidationError.emptyTitle
        }

        return (
            normalizedTitle,
            documentType.trimmingCharacters(in: .whitespacesAndNewlines),
            fileName.trimmingCharacters(in: .whitespacesAndNewlines),
            extractedText.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }
}
