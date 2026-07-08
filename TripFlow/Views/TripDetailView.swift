//
//  TripDetailView.swift
//  TripFlow
//
//  Created by Vu Minh Khoi Ha on 06.07.26.
//

import SwiftUI
import SwiftData
import MapKit

struct TripDetailView: View {
    @Environment(\.modelContext) private var modelContext
    private let trip: Trip
    @State private var viewModel: TripDetailViewModel

    init(trip: Trip) {
        self.trip = trip
        _viewModel = State(initialValue: TripDetailViewModel(trip: trip))
    }

    var body: some View {
        Form {
            planningStatusSection

            Section("Trip") {
                TextField("Name", text: $viewModel.title)
            }

            Section("Reisedaten") {
                Toggle("Startdatum", isOn: $viewModel.hasStartDate)
                    .onChange(of: viewModel.hasStartDate) { _, newValue in
                        viewModel.setStartDateEnabled(newValue)
                    }

                if viewModel.hasStartDate {
                    DatePicker(
                        "Start",
                        selection: startDateBinding,
                        displayedComponents: .date
                    )
                }

                Toggle("Enddatum", isOn: $viewModel.hasEndDate)
                    .onChange(of: viewModel.hasEndDate) { _, newValue in
                        viewModel.setEndDateEnabled(newValue)
                    }

                if viewModel.hasEndDate {
                    DatePicker(
                        "Ende",
                        selection: endDateBinding,
                        displayedComponents: .date
                    )
                }
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

            if let stopSuccessMessage = viewModel.stopSuccessMessage {
                Text(stopSuccessMessage)
                    .font(.footnote)
                    .foregroundStyle(.green)
            }

            timelineSection
            mapSection
            documentsSection

            Section("Stops") {
                let stops = viewModel.sortedStops(for: trip)

                if stops.isEmpty {
                    Text("Noch keine Stops")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(stops) { stop in
                        stopRow(stop)
                    }
                    .onDelete { offsets in
                        viewModel.deleteStops(stops, at: offsets, from: trip, in: modelContext)
                    }
                }
            }
        }
        .navigationTitle(trip.title)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    viewModel.showCreateStop()
                } label: {
                    Label("Stop erstellen", systemImage: "plus")
                }
            }

            ToolbarItem(placement: .confirmationAction) {
                Button("Speichern") {
                    viewModel.save(trip: trip)
                }
                .disabled(viewModel.canSave == false)
            }
        }
        .sheet(isPresented: $viewModel.isShowingCreateStop) {
            createStopSheet
        }
        .sheet(isPresented: $viewModel.isShowingCreateDocument) {
            createDocumentSheet
        }
    }

    private var planningStatusSection: some View {
        Section("Planungsstand") {
            let summary = viewModel.planningSummary(for: trip)

            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(summary.dateRangeText)
                        .font(.subheadline)

                    HStack(spacing: 8) {
                        Label(summary.stopCountText, systemImage: "mappin.and.ellipse")
                        Label(summary.documentCountText, systemImage: "doc.text")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                Spacer()

                Text(summary.status.title)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(statusForegroundStyle(for: summary.status))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(statusBackgroundStyle(for: summary.status), in: Capsule())
            }
            .padding(.vertical, 2)
        }
    }

    private var timelineSection: some View {
        Section("Timeline") {
            let timeline = viewModel.timeline(for: trip)

            if timeline.days.isEmpty && timeline.unscheduledStops.isEmpty {
                Text("Noch keine Timeline")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(timeline.days) { day in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(viewModel.timelineDayTitle(for: day))
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)

                        ForEach(day.stops) { stop in
                            timelineStopRow(stop)
                        }
                    }
                    .padding(.vertical, 4)
                }

                if timeline.unscheduledStops.isEmpty == false {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Ohne Datum")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)

                        ForEach(timeline.unscheduledStops) { stop in
                            timelineStopRow(stop)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    private var mapSection: some View {
        Section("Karte") {
            let mapStops = viewModel.mapStops(for: trip)

            if mapStops.isEmpty {
                Text("Noch keine Orte mit Koordinaten")
                    .foregroundStyle(.secondary)
            } else {
                Map(initialPosition: .region(viewModel.mapRegion(for: mapStops))) {
                    ForEach(mapStops) { mapStop in
                        Marker(mapStop.title, coordinate: mapStop.coordinate)
                    }
                }
                .frame(height: 220)
                .clipShape(RoundedRectangle(cornerRadius: 8))

                ForEach(mapStops) { mapStop in
                    VStack(alignment: .leading, spacing: 3) {
                        Text(mapStop.title)
                            .font(.subheadline)

                        if mapStop.locationName.isEmpty == false {
                            Text(mapStop.locationName)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }

    private var documentsSection: some View {
        Section("Reiseunterlagen") {
            let documents = viewModel.sortedDocuments(for: trip)

            if documents.isEmpty {
                Text("Noch keine Reiseunterlagen")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(documents) { document in
                    documentRow(document)
                        .swipeActions {
                            if viewModel.parsedScheduleDate(for: document) != nil {
                                Button {
                                    viewModel.showCreateStop(from: document)
                                } label: {
                                    Label("Stop", systemImage: "calendar.badge.plus")
                                }
                                .tint(.blue)
                            }
                        }
                }
                .onDelete { offsets in
                    viewModel.deleteDocuments(documents, at: offsets, from: trip, in: modelContext)
                }
            }

            Button {
                viewModel.showCreateDocument()
            } label: {
                Label("Reiseunterlage hinzufügen", systemImage: "doc.badge.plus")
            }
        }
    }

    private func timelineStopRow(_ stop: Stop) -> some View {
        NavigationLink {
            StopDetailView(stop: stop)
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(viewModel.timelineTimeTitle(for: stop) ?? "--:--")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 48, alignment: .leading)

                VStack(alignment: .leading, spacing: 3) {
                    Text(stop.title)
                        .font(.body)

                    if stop.locationName.isEmpty == false {
                        Text(stop.locationName)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.vertical, 2)
        }
    }

    private func stopRow(_ stop: Stop) -> some View {
        NavigationLink {
            StopDetailView(stop: stop)
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(stop.title)
                    .font(.headline)

                if let subtitle = viewModel.stopSubtitle(for: stop) {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 4)
        }
    }

    private func documentRow(_ document: TravelDocument) -> some View {
        NavigationLink {
            TravelDocumentDetailView(document: document)
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(document.title)
                    .font(.headline)

                if let subtitle = viewModel.documentSubtitle(for: document) {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                if document.extractedText.isEmpty == false {
                    Text(document.extractedText)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            .padding(.vertical, 4)
        }
    }

    private var startDateBinding: Binding<Date> {
        Binding {
            viewModel.startDate ?? Date()
        } set: { newValue in
            viewModel.startDate = newValue
        }
    }

    private var endDateBinding: Binding<Date> {
        Binding {
            viewModel.endDate ?? viewModel.startDate ?? Date()
        } set: { newValue in
            viewModel.endDate = newValue
        }
    }

    private func statusForegroundStyle(for status: TripPlanningStatus) -> Color {
        switch status {
        case .empty:
            return .secondary
        case .planning:
            return .blue
        case .ready:
            return .green
        }
    }

    private func statusBackgroundStyle(for status: TripPlanningStatus) -> Color {
        statusForegroundStyle(for: status).opacity(0.12)
    }

    private var createStopSheet: some View {
        NavigationStack {
            Form {
                if viewModel.isReviewingDocumentStopSuggestion {
                    Section("Aus Dokument erkannt") {
                        LabeledContent("Stop-Name", value: viewModel.newStopTitle)

                        if let scheduledDate = viewModel.newStopScheduledDate {
                            LabeledContent("Datum", value: scheduledDate.formatted(.dateTime.day().month().year()))
                            LabeledContent("Uhrzeit", value: scheduledDate.formatted(.dateTime.hour().minute()))
                        }

                        if viewModel.newStopLocationName.isEmpty == false {
                            LabeledContent("Ort", value: viewModel.newStopLocationName)
                        }
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
                }

                Section(viewModel.isReviewingDocumentStopSuggestion ? "Vor dem Speichern bearbeiten" : "Stop") {
                    TextField("Stop-Name", text: $viewModel.newStopTitle)
                    TextField("Ort optional", text: $viewModel.newStopLocationName)
                }

                Section("Koordinaten") {
                    TextField("Latitude optional", text: $viewModel.newStopLatitudeText)
                        .keyboardType(.numbersAndPunctuation)
                    TextField("Longitude optional", text: $viewModel.newStopLongitudeText)
                        .keyboardType(.numbersAndPunctuation)

                    Button {
                        Task {
                            await viewModel.fillNewStopCoordinatesFromLocationName()
                        }
                    } label: {
                        Label(
                            viewModel.isReviewingDocumentStopSuggestion ? "Koordinaten aus erkanntem Ort setzen" : "Koordinaten aus Ort setzen",
                            systemImage: "location"
                        )
                    }
                    .disabled(viewModel.canFillNewStopCoordinatesFromLocationName == false)

                    if let newStopCoordinateLookupDisabledReason = viewModel.newStopCoordinateLookupDisabledReason {
                        Text(newStopCoordinateLookupDisabledReason)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Zeitpunkt") {
                    if viewModel.isReviewingDocumentStopSuggestion {
                        DatePicker(
                            "Datum und Uhrzeit",
                            selection: newStopScheduledDateBinding,
                            displayedComponents: [.date, .hourAndMinute]
                        )
                    } else {
                        Toggle("Datum und Uhrzeit", isOn: $viewModel.newStopHasScheduledDate)
                            .onChange(of: viewModel.newStopHasScheduledDate) { _, newValue in
                                viewModel.setNewStopScheduledDateEnabled(newValue)
                            }

                        if viewModel.newStopHasScheduledDate {
                            DatePicker(
                                "Zeit",
                                selection: newStopScheduledDateBinding,
                                displayedComponents: [.date, .hourAndMinute]
                            )
                        }
                    }
                }

                if let stopErrorMessage = viewModel.stopErrorMessage {
                    Text(stopErrorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }

                if viewModel.isReviewingDocumentStopSuggestion,
                   let createStopDisabledReason = viewModel.createStopDisabledReason {
                    Text(createStopDisabledReason)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Neuer Stop")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") {
                        viewModel.cancelCreateStop()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Erstellen") {
                        viewModel.createStop(for: trip, in: modelContext)
                    }
                    .disabled(viewModel.canCreateStop == false)
                }
            }
            .presentationDetents([.medium])
        }
    }

    private var createDocumentSheet: some View {
        NavigationStack {
            Form {
                Section("Reiseunterlage") {
                    TextField("Name", text: $viewModel.newDocumentTitle)
                    TextField("Typ optional", text: $viewModel.newDocumentType)
                    TextField("Dateiname optional", text: $viewModel.newDocumentFileName)
                }

                Section("Text") {
                    TextEditor(text: $viewModel.newDocumentExtractedText)
                        .frame(minHeight: 120)

                    Text(viewModel.newDocumentExtractedTextHint)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                if let documentErrorMessage = viewModel.documentErrorMessage {
                    Text(documentErrorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }

                if let createDocumentDisabledReason = viewModel.createDocumentDisabledReason {
                    Text(createDocumentDisabledReason)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Neue Unterlage")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") {
                        viewModel.cancelCreateDocument()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Erstellen") {
                        viewModel.createDocument(for: trip, in: modelContext)
                    }
                    .disabled(viewModel.canCreateDocument == false)
                }
            }
            .presentationDetents([.medium, .large])
        }
    }

    private var newStopScheduledDateBinding: Binding<Date> {
        Binding {
            viewModel.newStopScheduledDate ?? viewModel.startDate ?? Date()
        } set: { newValue in
            viewModel.newStopScheduledDate = newValue
        }
    }
}

#Preview {
    NavigationStack {
        let trip = Trip(title: "Berlin")
        trip.documents = [
            TravelDocument(
                title: "Hotelbuchung",
                documentType: "Hotel",
                fileName: "hotel.pdf",
                extractedText: "Check-in 15:00, Reservierung 12345"
            ),
        ]

        return TripDetailView(trip: trip)
    }
    .modelContainer(for: [Trip.self, Stop.self, TravelDocument.self], inMemory: true)
}
