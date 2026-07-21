//
//  TravelDocumentScannerView.swift
//  TripFlow
//
//  Created by Codex on 21.07.26.
//

import SwiftUI
import VisionKit

struct TravelDocumentScannerView: UIViewControllerRepresentable {
    let onScan: ([Data]) -> Void
    let onCancel: () -> Void
    let onFailure: () -> Void

    static var isSupported: Bool {
        VNDocumentCameraViewController.isSupported
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let scanner = VNDocumentCameraViewController()
        scanner.delegate = context.coordinator
        return scanner
    }

    func updateUIViewController(
        _ uiViewController: VNDocumentCameraViewController,
        context: Context
    ) {}

    final class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        private let parent: TravelDocumentScannerView

        init(parent: TravelDocumentScannerView) {
            self.parent = parent
        }

        func documentCameraViewController(
            _ controller: VNDocumentCameraViewController,
            didFinishWith scan: VNDocumentCameraScan
        ) {
            var pages: [Data] = []

            for index in 0..<scan.pageCount {
                guard let pageData = scan.imageOfPage(at: index).jpegData(compressionQuality: 0.9) else {
                    parent.onFailure()
                    return
                }

                pages.append(pageData)
            }

            parent.onScan(pages)
        }

        func documentCameraViewControllerDidCancel(
            _ controller: VNDocumentCameraViewController
        ) {
            parent.onCancel()
        }

        func documentCameraViewController(
            _ controller: VNDocumentCameraViewController,
            didFailWithError error: Error
        ) {
            parent.onFailure()
        }
    }
}
