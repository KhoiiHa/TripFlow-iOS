//
//  TripDetailView.swift
//  TripFlow
//
//  Created by Vu Minh Khoi Ha on 06.07.26.
//

import SwiftUI
import SwiftData

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

            Section("Stops") {
                let stops = viewModel.sortedStops(for: trip)

                if stops.isEmpty {
                    Text("Noch keine Stops")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(stops) { stop in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(stop.title)
                                .font(.headline)

                            if stop.locationName.isEmpty == false {
                                Text(stop.locationName)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
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
                Section {
                    TextField("Stop-Name", text: $viewModel.newStopTitle)
                    TextField("Ort optional", text: $viewModel.newStopLocationName)
                }

                if let stopErrorMessage = viewModel.stopErrorMessage {
                    Text(stopErrorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }
            .navigationTitle("Neuer Stop")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") {
                        viewModel.isShowingCreateStop = false
                        viewModel.stopErrorMessage = nil
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
}

#Preview {
    NavigationStack {
        TripDetailView(trip: Trip(title: "Berlin"))
    }
    .modelContainer(for: [Trip.self, Stop.self], inMemory: true)
}
