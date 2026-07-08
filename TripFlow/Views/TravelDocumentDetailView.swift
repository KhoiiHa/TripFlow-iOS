//
//  TravelDocumentDetailView.swift
//  TripFlow
//
//  Created by Vu Minh Khoi Ha on 07.07.26.
//

import SwiftUI
import SwiftData

struct TravelDocumentDetailView: View {
    @Environment(\.modelContext) private var modelContext
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

                    if let flightNumber = viewModel.parsedFlightNumber() {
                        LabeledContent("Flugnummer", value: flightNumber)
                    }

                    if let reservationNumber = viewModel.parsedReservationNumber() {
                        LabeledContent("Reservierungsnummer", value: reservationNumber)
                    }

                    if viewModel.canShowStopSuggestionAction(for: document) {
                        Button {
                            viewModel.showStopSuggestion(from: document)
                        } label: {
                            Label("Stop daraus erstellen", systemImage: "calendar.badge.plus")
                        }
                    }
                }
            }

            if let stopSuggestionSuccessMessage = viewModel.stopSuggestionSuccessMessage {
                Text(stopSuggestionSuccessMessage)
                    .font(.footnote)
                    .foregroundStyle(.green)
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
        .sheet(isPresented: $viewModel.isShowingStopSuggestion) {
            stopSuggestionSheet
        }
    }

    private var stopSuggestionSheet: some View {
        NavigationStack {
            Form {
                Section("Vorschlag prüfen") {
                    TextField("Stop-Name", text: $viewModel.stopSuggestionTitle)
                    TextField("Ort optional", text: $viewModel.stopSuggestionLocationName)
                    DatePicker(
                        "Datum und Uhrzeit",
                        selection: stopSuggestionScheduledDateBinding,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                }

                if viewModel.stopSuggestionTextExcerpt.isEmpty == false
                    || viewModel.stopSuggestionDocumentType.isEmpty == false {
                    Section("Quelle") {
                        if viewModel.stopSuggestionTextExcerpt.isEmpty == false {
                            LabeledContent("Textausschnitt", value: viewModel.stopSuggestionTextExcerpt)
                        }

                        if viewModel.stopSuggestionDocumentType.isEmpty == false {
                            LabeledContent("Dokumenttyp", value: viewModel.stopSuggestionDocumentType)
                        }
                    }
                }

                if let stopSuggestionErrorMessage = viewModel.stopSuggestionErrorMessage {
                    Text(stopSuggestionErrorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }
            .navigationTitle("Neuer Stop")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") {
                        viewModel.isShowingStopSuggestion = false
                        viewModel.stopSuggestionErrorMessage = nil
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Erstellen") {
                        viewModel.createStopSuggestion(from: document, in: modelContext)
                    }
                    .disabled(viewModel.canCreateStopSuggestion == false)
                }
            }
        }
    }

    private var stopSuggestionScheduledDateBinding: Binding<Date> {
        Binding {
            viewModel.stopSuggestionScheduledDate ?? Date()
        } set: { newValue in
            viewModel.stopSuggestionScheduledDate = newValue
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
