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
                    emptyTripsView
                        .listRowInsets(EdgeInsets(top: 48, leading: 24, bottom: 24, trailing: 24))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                } else {
                    ForEach(trips) { trip in
                        NavigationLink {
                            TripDetailView(trip: trip)
                        } label: {
                            tripCard(trip)
                        }
                        .buttonStyle(.plain)
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                    }
                    .onDelete { offsets in
                        viewModel.deleteTrips(trips, at: offsets, in: modelContext)
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Color(.systemGroupedBackground))
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

    private var emptyTripsView: some View {
        ContentUnavailableView {
            Label("Noch keine Trips", systemImage: "airplane.departure")
                .foregroundStyle(.blue)
        } description: {
            Text("Erstelle deinen ersten Trip und plane Stops, Unterlagen und Orte an einem Platz.")
        } actions: {
            Button {
                viewModel.showCreateTrip()
            } label: {
                Label("Trip erstellen", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private func tripCard(_ trip: Trip) -> some View {
        let summary = viewModel.planningSummary(for: trip)

        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "airplane.departure")
                    .font(.title3)
                    .foregroundStyle(.blue)
                    .frame(width: 34, height: 34)
                    .background(.blue.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 6) {
                    Text(trip.title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Label(summary.dateRangeText, systemImage: "calendar")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                TripPlanningStatusBadge(status: summary.status)
            }

            Divider()

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 10) {
                    tripMetricLabel(summary.stopCountText, systemImage: "mappin.and.ellipse")
                    tripMetricLabel(summary.documentCountText, systemImage: "doc.text")
                    Spacer()
                }

                VStack(alignment: .leading, spacing: 8) {
                    tripMetricLabel(summary.stopCountText, systemImage: "mappin.and.ellipse")
                    tripMetricLabel(summary.documentCountText, systemImage: "doc.text")
                }
            }
        }
        .padding(16)
        .background(.background, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(.quaternary, lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 4)
        .accessibilityElement(children: .combine)
    }

    private func tripMetricLabel(_ title: String, systemImage: String) -> some View {
        Label {
            Text(title)
                .lineLimit(1)
        } icon: {
            Image(systemName: systemImage)
                .foregroundStyle(.blue)
        }
        .font(.caption)
        .fontWeight(.medium)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(.blue.opacity(0.08), in: Capsule())
    }

    private var createTripSheet: some View {
        NavigationStack {
            Form {
                Section("Trip") {
                    TextField("Trip-Name", text: $viewModel.newTripTitle)
                }

                Section("Reisedaten optional") {
                    Toggle("Startdatum", isOn: $viewModel.newTripHasStartDate)

                    if viewModel.newTripHasStartDate {
                        DatePicker(
                            "Start",
                            selection: $viewModel.newTripStartDate,
                            displayedComponents: .date
                        )
                    }

                    Toggle("Enddatum", isOn: $viewModel.newTripHasEndDate)

                    if viewModel.newTripHasEndDate {
                        DatePicker(
                            "Ende",
                            selection: $viewModel.newTripEndDate,
                            displayedComponents: .date
                        )
                    }
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
