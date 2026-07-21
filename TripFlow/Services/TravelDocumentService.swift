//
//  TravelDocumentService.swift
//  TripFlow
//
//  Created by Vu Minh Khoi Ha on 06.07.26.
//

import Foundation

enum TravelDocumentValidationError: Error, Equatable {
    case emptyTitle
    case duplicateSource
}

struct TravelDocumentService {
    func createDocument(
        title: String,
        documentType: String = "",
        fileName: String = "",
        extractedText: String = "",
        sourceData: Data? = nil,
        sourceFingerprint: String? = nil,
        for trip: Trip
    ) throws -> TravelDocument {
        let values = try validate(title: title, documentType: documentType, fileName: fileName, extractedText: extractedText)

        if let sourceFingerprint,
           let sourceData,
           trip.documents.contains(where: { document in
               document.sourceFingerprint == sourceFingerprint
                   || (document.sourceFingerprint == nil && document.sourceData == sourceData)
           }) {
            throw TravelDocumentValidationError.duplicateSource
        }

        let document = TravelDocument(
            title: values.title,
            documentType: values.documentType,
            fileName: values.fileName,
            extractedText: values.extractedText,
            sourceData: sourceData,
            sourceFingerprint: sourceFingerprint,
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
