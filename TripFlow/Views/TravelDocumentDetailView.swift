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
                    recognitionSummaryRow(item)
                }
            }
        }
    }

    @ViewBuilder
    private var parsedTravelDataSection: some View {
        if viewModel.hasParsedTravelData() {
            Section("Erkannte Reisedaten") {
                if let suggestedStopTitle = viewModel.parsedSuggestedStopTitle() {
                    parsedTravelDataRow(
                        title: "Stop-Vorschlag",
                        value: suggestedStopTitle,
                        systemImage: "mappin.and.ellipse"
                    )
                }

                if let parsedScheduleText = viewModel.parsedScheduleText() {
                    parsedTravelDataRow(
                        title: "Datum und Uhrzeit",
                        value: parsedScheduleText,
                        systemImage: "calendar"
                    )
                }

                if let suggestedLocationName = viewModel.parsedSuggestedLocationName() {
                    parsedTravelDataRow(
                        title: "Ort",
                        value: suggestedLocationName,
                        systemImage: "location"
                    )
                }

                if let flightNumber = viewModel.parsedFlightNumber() {
                    parsedTravelDataRow(
                        title: "Flugnummer",
                        value: flightNumber,
                        systemImage: "airplane"
                    )
                }

                if let trainNumber = viewModel.parsedTrainNumber() {
                    parsedTravelDataRow(
                        title: "Zugnummer",
                        value: trainNumber,
                        systemImage: "tram"
                    )
                }

                if let reservationNumber = viewModel.parsedReservationNumber() {
                    parsedTravelDataRow(
                        title: "Reservierungsnummer",
                        value: reservationNumber,
                        systemImage: "number"
                    )
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
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: systemImage)
                    .font(.headline)
                    .foregroundStyle(.blue)
                    .frame(width: 30, height: 30)
                    .background(.blue.opacity(0.10), in: RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 8)
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
                    Label {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Bitte prüfe die erkannten Werte, bevor daraus ein Stop gespeichert wird.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "checklist")
                            .foregroundStyle(.blue)
                    }

                    stopSuggestionReviewRow(
                        title: "Stop-Name",
                        value: viewModel.stopSuggestionTitle,
                        systemImage: "mappin.and.ellipse"
                    )

                    if let scheduledDate = viewModel.stopSuggestionScheduledDate {
                        stopSuggestionReviewRow(
                            title: "Datum",
                            value: DateDisplayFormatter.date(scheduledDate),
                            systemImage: "calendar"
                        )
                        stopSuggestionReviewRow(
                            title: "Uhrzeit",
                            value: DateDisplayFormatter.time(scheduledDate),
                            systemImage: "clock"
                        )
                    }

                    if viewModel.stopSuggestionLocationName.isEmpty == false {
                        stopSuggestionReviewRow(
                            title: "Ort",
                            value: viewModel.stopSuggestionLocationName,
                            systemImage: "location"
                        )
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
                        ViewThatFits(in: .horizontal) {
                            HStack(spacing: 8) {
                                stopSuggestionSourceBadges
                            }

                            VStack(alignment: .leading, spacing: 8) {
                                stopSuggestionSourceBadges
                            }
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

    private func recognitionSummaryRow(_ item: TravelDocumentRecognitionSummaryItem) -> some View {
        Label {
            VStack(alignment: .leading, spacing: 3) {
                Text(item.title)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)

                Text(item.value)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .lineLimit(2)
            }
        } icon: {
            Image(systemName: item.systemImage)
                .font(.headline)
                .foregroundStyle(.blue)
                .frame(width: 30, height: 30)
                .background(.blue.opacity(0.10), in: RoundedRectangle(cornerRadius: 8))
        }
        .padding(.vertical, 4)
    }

    private func parsedTravelDataRow(title: String, value: String, systemImage: String) -> some View {
        Label {
            LabeledContent(title, value: value)
                .font(.subheadline)
        } icon: {
            Image(systemName: systemImage)
                .foregroundStyle(.blue)
        }
        .padding(.vertical, 2)
    }

    private func stopSuggestionReviewRow(title: String, value: String, systemImage: String) -> some View {
        Label {
            LabeledContent(title, value: value)
                .font(.subheadline)
        } icon: {
            Image(systemName: systemImage)
                .foregroundStyle(.blue)
        }
    }

    @ViewBuilder
    private var stopSuggestionSourceBadges: some View {
        if viewModel.stopSuggestionDocumentType.isEmpty == false {
            sourceBadge(viewModel.stopSuggestionDocumentType, systemImage: "doc.text")
        }

        if viewModel.stopSuggestionFlightNumber.isEmpty == false {
            sourceBadge(viewModel.stopSuggestionFlightNumber, systemImage: "airplane")
        }

        if viewModel.stopSuggestionTrainNumber.isEmpty == false {
            sourceBadge(viewModel.stopSuggestionTrainNumber, systemImage: "tram")
        }

        if viewModel.stopSuggestionReservationNumber.isEmpty == false {
            sourceBadge(viewModel.stopSuggestionReservationNumber, systemImage: "number")
        }
    }

    private func sourceBadge(_ title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundStyle(.blue)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.blue.opacity(0.10), in: Capsule())
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
