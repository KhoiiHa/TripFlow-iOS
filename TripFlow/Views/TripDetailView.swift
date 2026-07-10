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
            timelineSection
            mapSection
            stopsSection
            documentsSection
            tripEditingSection
            travelDatesEditingSection
            tripMessagesSection
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

    private var tripEditingSection: some View {
        Section("Trip bearbeiten") {
            TextField("Name", text: $viewModel.title)
        }
    }

    private var travelDatesEditingSection: some View {
        Section("Reisedaten bearbeiten") {
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
    }

    @ViewBuilder
    private var tripMessagesSection: some View {
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

                TripPlanningStatusBadge(status: summary.status)
            }
            .padding(.vertical, 2)
        }
    }

    private var stopsSection: some View {
        Section("Stops") {
            let stops = viewModel.sortedStops(for: trip)

            if stops.isEmpty {
                tripDetailEmptyState(
                    title: "Noch keine Stops",
                    systemImage: "mappin.and.ellipse",
                    message: "Lege den ersten geplanten Ort fuer diesen Trip an.",
                    actionTitle: "Stop hinzufügen",
                    actionSystemImage: "plus"
                ) {
                    viewModel.showCreateStop()
                }
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

    private var timelineSection: some View {
        Section("Timeline") {
            let timeline = viewModel.timeline(for: trip)

            if timeline.days.isEmpty && timeline.unscheduledStops.isEmpty {
                tripDetailEmptyState(
                    title: "Noch keine Timeline",
                    systemImage: "calendar",
                    message: "Plane einen Stop mit Datum, um die Tagesansicht zu fuellen.",
                    actionTitle: "Stop planen",
                    actionSystemImage: "calendar.badge.plus"
                ) {
                    viewModel.showCreateStop()
                }
            } else {
                ForEach(timeline.days) { day in
                    VStack(alignment: .leading, spacing: 8) {
                        Label(viewModel.timelineDayTitle(for: day), systemImage: "calendar")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)

                        ForEach(day.stops) { stop in
                            timelineStopRow(stop, isUnscheduled: false)
                        }
                    }
                    .padding(.vertical, 4)
                }

                if timeline.unscheduledStops.isEmpty == false {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Ohne Datum", systemImage: "calendar.badge.exclamationmark")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)

                        ForEach(timeline.unscheduledStops) { stop in
                            timelineStopRow(stop, isUnscheduled: true)
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
                tripDetailEmptyState(
                    title: "Noch keine Orte mit Koordinaten",
                    systemImage: "map",
                    message: "Fuege einem Stop einen Ort oder Koordinaten hinzu.",
                    actionTitle: "Stop mit Ort hinzufügen",
                    actionSystemImage: "mappin.and.ellipse"
                ) {
                    viewModel.showCreateStop()
                }
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
                tripDetailEmptyState(
                    title: "Noch keine Reiseunterlagen",
                    systemImage: "doc.text",
                    message: "Importiere Tickets, Buchungen oder Reservierungen fuer diesen Trip.",
                    actionTitle: "Unterlage hinzufügen",
                    actionSystemImage: "doc.badge.plus"
                ) {
                    viewModel.showCreateDocument()
                }
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

    private func tripDetailEmptyState(
        title: String,
        systemImage: String,
        message: String,
        actionTitle: String,
        actionSystemImage: String,
        action: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: systemImage)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            Text(message)
                .font(.footnote)
                .foregroundStyle(.secondary)

            Button(action: action) {
                Label(actionTitle, systemImage: actionSystemImage)
            }
            .font(.footnote)
        }
        .padding(.vertical, 4)
    }

    private func timelineStopRow(_ stop: Stop, isUnscheduled: Bool) -> some View {
        NavigationLink {
            StopDetailView(stop: stop)
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(viewModel.timelineTimeTitle(for: stop) ?? "Offen")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(isUnscheduled ? Color.secondary : Color.blue)
                    .frame(width: 52, alignment: .leading)

                VStack(alignment: .leading, spacing: 3) {
                    Text(stop.title)
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    if stop.locationName.isEmpty == false {
                        Label(stop.locationName, systemImage: "mappin.and.ellipse")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.vertical, 4)
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
            let badges = viewModel.documentMetadataBadges(for: document)

            VStack(alignment: .leading, spacing: 6) {
                Text(document.title)
                    .font(.headline)

                if badges.isEmpty == false {
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 8) {
                            ForEach(badges) { badge in
                                documentMetadataBadge(badge)
                            }
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(badges) { badge in
                                documentMetadataBadge(badge)
                            }
                        }
                    }
                }

                if let detailText = viewModel.documentListDetailText(for: document) {
                    Text(detailText)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
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

    private func documentMetadataBadge(_ badge: DocumentMetadataBadge) -> some View {
        Label(badge.title, systemImage: badge.systemImage)
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundStyle(badge.isHighlighted ? Color.blue : Color.secondary)
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

    private var createStopSheet: some View {
        NavigationStack {
            Form {
                if viewModel.isReviewingDocumentStopSuggestion {
                    Section("Aus Dokument erkannt") {
                        LabeledContent("Stop-Name", value: viewModel.newStopTitle)

                        if let scheduledDate = viewModel.newStopScheduledDate {
                            LabeledContent("Datum", value: DateDisplayFormatter.date(scheduledDate))
                            LabeledContent("Uhrzeit", value: DateDisplayFormatter.time(scheduledDate))
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
                }

                Section(viewModel.isReviewingDocumentStopSuggestion ? "Zeitpunkt bestaetigen" : "Zeitpunkt optional") {
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
                                "Datum und Uhrzeit",
                                selection: newStopScheduledDateBinding,
                                displayedComponents: [.date, .hourAndMinute]
                            )
                        }
                    }
                }

                Section("Ort und Koordinaten") {
                    TextField("Ort optional", text: $viewModel.newStopLocationName)

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

                if let stopErrorMessage = viewModel.stopErrorMessage {
                    Text(stopErrorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }

                if let createStopDisabledReason = viewModel.createStopDisabledReason {
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

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(viewModel.newDocumentTypeSuggestions, id: \.self) { suggestion in
                                Button {
                                    viewModel.applyNewDocumentTypeSuggestion(suggestion)
                                } label: {
                                    Text(suggestion)
                                        .font(.caption)
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }

                Section("Datei") {
                    TextField("Dateiname optional", text: $viewModel.newDocumentFileName)
                }

                Section("OCR-Text optional") {
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
