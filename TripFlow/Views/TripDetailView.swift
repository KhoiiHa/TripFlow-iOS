//
//  TripDetailView.swift
//  TripFlow
//
//  Created by Vu Minh Khoi Ha on 06.07.26.
//

import SwiftUI

struct TripDetailView: View {
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
        }
        .navigationTitle(trip.title)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Speichern") {
                    viewModel.save(trip: trip)
                }
                .disabled(viewModel.canSave == false)
            }
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
}

#Preview {
    NavigationStack {
        TripDetailView(trip: Trip(title: "Berlin"))
    }
}
