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
        HStack(spacing: 5) {
            Circle()
                .fill(foregroundStyle)
                .frame(width: 6, height: 6)

            Text(status.title)
                .lineLimit(1)
        }
        .font(.caption)
        .fontWeight(.semibold)
        .foregroundStyle(foregroundStyle)
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
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
