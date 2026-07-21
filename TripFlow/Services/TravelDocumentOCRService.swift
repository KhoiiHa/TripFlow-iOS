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
    func recognizeText(inImageData pages: [Data]) async throws -> String
}

struct TravelDocumentOCRService: TravelDocumentTextRecognizing {
    func recognizeText(inImageAt url: URL) async throws -> String {
        let hasSecurityScopedAccess = url.startAccessingSecurityScopedResource()
        defer {
            if hasSecurityScopedAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }

        guard let imageData = try? Data(contentsOf: url) else {
            throw TravelDocumentOCRError.unreadableImage
        }

        return try await recognizeText(inImageData: [imageData])
    }

    func recognizeText(inImageData pages: [Data]) async throws -> String {
        guard pages.isEmpty == false else {
            throw TravelDocumentOCRError.unreadableImage
        }

        var recognizedPages: [String] = []

        for page in pages {
            guard let image = UIImage(data: page),
                  let cgImage = image.cgImage else {
                throw TravelDocumentOCRError.unreadableImage
            }

            let text = try await recognizeText(
                in: cgImage,
                orientation: CGImagePropertyOrientation(image.imageOrientation)
            )

            if text.isEmpty == false {
                recognizedPages.append(text)
            }
        }

        guard recognizedPages.isEmpty == false else {
            throw TravelDocumentOCRError.noRecognizedText
        }

        return recognizedPages.joined(separator: "\n\n")
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
