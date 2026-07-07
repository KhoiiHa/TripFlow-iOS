//
//  TravelDocumentDetailView.swift
//  TripFlow
//
//  Created by Vu Minh Khoi Ha on 07.07.26.
//

import SwiftUI
import SwiftData

struct TravelDocumentDetailView: View {
    private let document: TravelDocument
    @State private var viewModel: TravelDocumentDetailViewModel

    init(document: TravelDocument) {
        self.document = document
        _viewModel = State(initialValue: TravelDocumentDetailViewModel(document: document))
    }

    var body: some View {
        Form {
            Section("Reiseunterlage") {
                TextField("Name", text: $viewModel.title)
                TextField("Typ optional", text: $viewModel.documentType)
                TextField("Dateiname optional", text: $viewModel.fileName)
            }

            Section("Text") {
                TextEditor(text: $viewModel.extractedText)
                    .frame(minHeight: 180)
            }

            if viewModel.hasParsedTravelData() {
                Section("Erkannte Reisedaten") {
                    if let suggestedStopTitle = viewModel.parsedSuggestedStopTitle() {
                        LabeledContent("Stop-Vorschlag", value: suggestedStopTitle)
                    }

                    if let parsedScheduleText = viewModel.parsedScheduleText() {
                        LabeledContent("Datum und Uhrzeit", value: parsedScheduleText)
                    }

                    if let suggestedLocationName = viewModel.parsedSuggestedLocationName() {
                        LabeledContent("Ort", value: suggestedLocationName)
                    }
                }
            }

            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
        }
        .navigationTitle(document.title)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Speichern") {
                    viewModel.save(document: document)
                }
                .disabled(viewModel.canSave == false)
            }
        }
    }
}

#Preview {
    NavigationStack {
        TravelDocumentDetailView(
            document: TravelDocument(
                title: "Hotelbuchung",
                documentType: "Hotel",
                fileName: "hotel.pdf",
                extractedText: "Check-in 15:00, Reservierung 12345"
            )
        )
    }
    .modelContainer(for: [Trip.self, Stop.self, TravelDocument.self], inMemory: true)
}
