//
//  TravelDocumentShareSheet.swift
//  TripFlow
//
//  Created by Codex on 21.07.26.
//

import SwiftUI
import UIKit

struct TravelDocumentShareSheet: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
