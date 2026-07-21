//
//  TravelDocumentOCRService.swift
//  TripFlow
//
//  Created by Codex on 21.07.26.
//

import Foundation
import ImageIO
import UIKit
@preconcurrency import Vision

enum TravelDocumentOCRError: Error {
    case unreadableImage
    case noRecognizedText
}

protocol TravelDocumentTextRecognizing {
    func recognizeText(inImageAt url: URL) async throws -> String
}

struct TravelDocumentOCRService: TravelDocumentTextRecognizing {
    func recognizeText(inImageAt url: URL) async throws -> String {
        let hasSecurityScopedAccess = url.startAccessingSecurityScopedResource()
        defer {
            if hasSecurityScopedAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }

        guard let image = UIImage(contentsOfFile: url.path),
              let cgImage = image.cgImage else {
            throw TravelDocumentOCRError.unreadableImage
        }

        return try await recognizeText(
            in: cgImage,
            orientation: CGImagePropertyOrientation(image.imageOrientation)
        )
    }

    private func recognizeText(
        in image: CGImage,
        orientation: CGImagePropertyOrientation
    ) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                let text = (request.results as? [VNRecognizedTextObservation])?
                    .compactMap { $0.topCandidates(1).first?.string }
                    .joined(separator: "\n")
                    .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

                guard text.isEmpty == false else {
                    continuation.resume(throwing: TravelDocumentOCRError.noRecognizedText)
                    return
                }

                continuation.resume(returning: text)
            }

            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true

            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try VNImageRequestHandler(
                        cgImage: image,
                        orientation: orientation
                    ).perform([request])
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}

private extension CGImagePropertyOrientation {
    init(_ orientation: UIImage.Orientation) {
        switch orientation {
        case .up: self = .up
        case .upMirrored: self = .upMirrored
        case .down: self = .down
        case .downMirrored: self = .downMirrored
        case .left: self = .left
        case .leftMirrored: self = .leftMirrored
        case .right: self = .right
        case .rightMirrored: self = .rightMirrored
        @unknown default: self = .up
        }
    }
}
