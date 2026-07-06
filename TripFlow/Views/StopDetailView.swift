//
//  StopDetailView.swift
//  TripFlow
//
//  Created by Vu Minh Khoi Ha on 06.07.26.
//

import SwiftUI
import SwiftData

struct StopDetailView: View {
    private let stop: Stop
    @State private var viewModel: StopDetailViewModel

    init(stop: Stop) {
        self.stop = stop
        _viewModel = State(initialValue: StopDetailViewModel(stop: stop))
    }

    var body: some View {
        Form {
            Section("Stop") {
                TextField("Name", text: $viewModel.title)
                TextField("Ort optional", text: $viewModel.locationName)
            }

            Section("Koordinaten") {
                TextField("Latitude optional", text: $viewModel.latitudeText)
                    .keyboardType(.numbersAndPunctuation)
                TextField("Longitude optional", text: $viewModel.longitudeText)
                    .keyboardType(.numbersAndPunctuation)

                Button {
                    Task {
                        await viewModel.fillCoordinatesFromLocationName()
                    }
                } label: {
                    Label("Aus Ort setzen", systemImage: "location")
                }
                .disabled(viewModel.locationName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isResolvingCoordinates)
            }

            Section("Zeitpunkt") {
                Toggle("Datum und Uhrzeit", isOn: $viewModel.hasScheduledDate)
                    .onChange(of: viewModel.hasScheduledDate) { _, newValue in
                        viewModel.setScheduledDateEnabled(newValue)
                    }

                if viewModel.hasScheduledDate {
                    DatePicker(
                        "Zeit",
                        selection: scheduledDateBinding,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                }
            }

            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
        }
        .navigationTitle(stop.title)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Speichern") {
                    viewModel.save(stop: stop)
                }
                .disabled(viewModel.canSave == false)
            }
        }
    }

    private var scheduledDateBinding: Binding<Date> {
        Binding {
            viewModel.scheduledDate ?? Date()
        } set: { newValue in
            viewModel.scheduledDate = newValue
        }
    }
}

#Preview {
    NavigationStack {
        StopDetailView(stop: Stop(title: "Hotel", locationName: "Mitte"))
    }
    .modelContainer(for: [Trip.self, Stop.self, TravelDocument.self], inMemory: true)
}
