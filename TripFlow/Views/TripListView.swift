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
                            let summary = viewModel.planningSummary(for: trip)

                            VStack(alignment: .leading, spacing: 8) {
                                HStack(alignment: .firstTextBaseline) {
                                    Text(trip.title)
                                        .font(.headline)

                                    Spacer()

                                    Text(summary.status.title)
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(statusForegroundStyle(for: summary.status))
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(statusBackgroundStyle(for: summary.status), in: Capsule())
                                }

                                Text(summary.dateRangeText)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)

                                HStack(spacing: 8) {
                                    Label(summary.stopCountText, systemImage: "mappin.and.ellipse")
                                    Label(summary.documentCountText, systemImage: "doc.text")
                                }
                                .font(.caption)
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
}

#Preview {
    TripListView()
        .modelContainer(for: [Trip.self, Stop.self, TravelDocument.self], inMemory: true)
}
