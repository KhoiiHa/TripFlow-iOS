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
            documentEditingSection
            recognitionSummarySection
            parsedTravelDataSection
            ocrTextSection
            documentMessagesSection
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

    private var documentEditingSection: some View {
        Section("Reiseunterlage bearbeiten") {
            TextField("Name", text: $viewModel.title)
            TextField("Typ optional", text: $viewModel.documentType)
            TextField("Dateiname optional", text: $viewModel.fileName)
        }
    }

    @ViewBuilder
    private var recognitionSummarySection: some View {
        let summaryItems = viewModel.recognitionSummaryItems()

        if summaryItems.isEmpty == false {
            Section("Review") {
                ForEach(summaryItems) { item in
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.title)
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            Text(item.value)
                                .font(.subheadline)
                        }
                    } icon: {
                        Image(systemName: item.systemImage)
                            .foregroundStyle(.blue)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var parsedTravelDataSection: some View {
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

                if let trainNumber = viewModel.parsedTrainNumber() {
                    LabeledContent("Zugnummer", value: trainNumber)
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
        } else if viewModel.hasExtractedText {
            Section("Erkannte Reisedaten") {
                documentEmptyState(
                    title: "Keine Reisedaten erkannt",
                    systemImage: "text.magnifyingglass",
                    message: "Der OCR-Text wurde gespeichert, enthaelt aber noch kein klares Datum, keine Uhrzeit oder keinen Ort."
                )
            }
        }
    }

    private var ocrTextSection: some View {
        Section("OCR-Text") {
            TextEditor(text: $viewModel.extractedText)
                .frame(minHeight: 180)

            if viewModel.hasExtractedText == false {
                documentEmptyState(
                    title: "Noch kein OCR-Text",
                    systemImage: "doc.text.viewfinder",
                    message: "Fuege erkannten Text ein, damit TripFlow Reisedaten und Stop-Vorschlaege ableiten kann."
                )
            }
        }
    }

    private func documentEmptyState(
        title: String,
        systemImage: String,
        message: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: systemImage)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            Text(message)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var documentMessagesSection: some View {
        if let stopSuggestionUnavailableMessage = viewModel.stopSuggestionUnavailableMessage(for: document) {
            Text(stopSuggestionUnavailableMessage)
                .font(.footnote)
                .foregroundStyle(.secondary)
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

        if let saveDisabledReason = viewModel.saveDisabledReason {
            Text(saveDisabledReason)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var stopSuggestionSheet: some View {
        NavigationStack {
            Form {
                Section("Aus Dokument erkannt") {
                    LabeledContent("Stop-Name", value: viewModel.stopSuggestionTitle)

                    if let scheduledDate = viewModel.stopSuggestionScheduledDate {
                        LabeledContent("Datum", value: scheduledDate.formatted(.dateTime.day().month().year()))
                        LabeledContent("Uhrzeit", value: scheduledDate.formatted(.dateTime.hour().minute()))
                    }

                    if viewModel.stopSuggestionLocationName.isEmpty == false {
                        LabeledContent("Ort", value: viewModel.stopSuggestionLocationName)
                    }
                }

                Section("Vor dem Speichern bearbeiten") {
                    TextField("Stop-Name", text: $viewModel.stopSuggestionTitle)
                    TextField("Ort optional", text: $viewModel.stopSuggestionLocationName)
                    DatePicker(
                        "Datum und Uhrzeit",
                        selection: stopSuggestionScheduledDateBinding,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                }

                if viewModel.stopSuggestionTextExcerpt.isEmpty == false
                    || viewModel.stopSuggestionDocumentType.isEmpty == false
                    || viewModel.stopSuggestionFlightNumber.isEmpty == false
                    || viewModel.stopSuggestionTrainNumber.isEmpty == false
                    || viewModel.stopSuggestionReservationNumber.isEmpty == false {
                    Section("Dokumentquelle") {
                        if viewModel.stopSuggestionDocumentType.isEmpty == false {
                            LabeledContent("Dokumenttyp", value: viewModel.stopSuggestionDocumentType)
                        }

                        if viewModel.stopSuggestionFlightNumber.isEmpty == false {
                            LabeledContent("Flugnummer", value: viewModel.stopSuggestionFlightNumber)
                        }

                        if viewModel.stopSuggestionTrainNumber.isEmpty == false {
                            LabeledContent("Zugnummer", value: viewModel.stopSuggestionTrainNumber)
                        }

                        if viewModel.stopSuggestionReservationNumber.isEmpty == false {
                            LabeledContent("Reservierungsnummer", value: viewModel.stopSuggestionReservationNumber)
                        }

                        if viewModel.stopSuggestionTextExcerpt.isEmpty == false {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Textausschnitt")
                                    .foregroundStyle(.secondary)

                                Text(viewModel.stopSuggestionTextExcerpt)
                                    .font(.footnote)
                                    .textSelection(.enabled)
                            }
                        }
                    }
                }

                if let stopSuggestionErrorMessage = viewModel.stopSuggestionErrorMessage {
                    Text(stopSuggestionErrorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }

                if let createStopSuggestionDisabledReason = viewModel.createStopSuggestionDisabledReason {
                    Text(createStopSuggestionDisabledReason)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Neuer Stop")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") {
                        viewModel.cancelStopSuggestionReview()
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
