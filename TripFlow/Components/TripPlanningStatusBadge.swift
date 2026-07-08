//
//  TripPlanningStatusBadge.swift
//  TripFlow
//
//  Created by Vu Minh Khoi Ha on 08.07.26.
//

import SwiftUI

struct TripPlanningStatusBadge: View {
    let status: TripPlanningStatus

    var body: some View {
        Text(status.title)
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundStyle(foregroundStyle)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(foregroundStyle.opacity(0.12), in: Capsule())
    }

    private var foregroundStyle: Color {
        switch status {
        case .empty:
            return .secondary
        case .planning:
            return .blue
        case .ready:
            return .green
        }
    }
}

#Preview {
    HStack {
        TripPlanningStatusBadge(status: .empty)
        TripPlanningStatusBadge(status: .planning)
        TripPlanningStatusBadge(status: .ready)
    }
    .padding()
}
