//
//  TravelDocument.swift
//  TripFlow
//
//  Created by Vu Minh Khoi Ha on 06.07.26.
//

import Foundation
import SwiftData

@Model
final class TravelDocument {
    var title: String
    var documentType: String
    var fileName: String
    var extractedText: String
    var createdAt: Date
    var updatedAt: Date
    var trip: Trip?

    init(
        title: String,
        documentType: String = "",
        fileName: String = "",
        extractedText: String = "",
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        trip: Trip? = nil
    ) {
        self.title = title
        self.documentType = documentType
        self.fileName = fileName
        self.extractedText = extractedText
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.trip = trip
    }
}
