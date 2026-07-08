//
//  TripListView.swift
//  TripFlow
//
//  Created by Vu Minh Khoi Ha on 05.07.26.
//

import SwiftData
import SwiftUI

struct TripListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Trip.createdAt, order: .reverse) private var trips: [Trip]
    @State private var viewModel = TripListViewModel()

    var body: some View {
        NavigationStack {
            List {
                if trips.isEmpty {
                    ContentUnavailableView(
                        "Noch keine Trips",
                        systemImage: "airplane.departure",
                        description: Text("Erstelle deinen ersten Trip, um deine Reiseplanung zu starten.")
                    )
                } else {
                    ForEach(trips) { trip in
                        NavigationLink {
                            TripDetailView(trip: trip)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(trip.title)
                                    .font(.headline)

                                Text(viewModel.dateSummary(for: trip))
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .onDelete { offsets in
                        viewModel.deleteTrips(trips, at: offsets, in: modelContext)
                    }
                }
            }
            .navigationTitle("Trips")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        viewModel.showCreateTrip()
                    } label: {
                        Label("Trip erstellen", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $viewModel.isShowingCreateTrip) {
                createTripSheet
            }
        }
    }

    private var createTripSheet: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Trip-Name", text: $viewModel.newTripTitle)
                }

                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }

                if let createTripDisabledReason = viewModel.createTripDisabledReason {
                    Text(createTripDisabledReason)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Neuer Trip")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") {
                        viewModel.cancelCreateTrip()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Erstellen") {
                        viewModel.createTrip(in: modelContext)
                    }
                    .disabled(viewModel.canCreateTrip == false)
                }
            }
            .presentationDetents([.medium])
        }
    }
}

#Preview {
    TripListView()
        .modelContainer(for: [Trip.self, Stop.self, TravelDocument.self], inMemory: true)
}
