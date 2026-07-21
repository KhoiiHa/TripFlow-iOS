//
//  TravelDocumentOCRService.swift
//  TripFlow
//
//  Created by Codex on 21.07.26.
//

import Foundation
import ImageIO
import PDFKit
import UIKit
@preconcurrency import Vision

enum TravelDocumentOCRError: Error {
    case unreadableImage
    case unreadablePDF
    case noRecognizedText
}

protocol TravelDocumentTextRecognizing {
    func recognizeText(inDocumentAt url: URL) async throws -> String
    func recognizeText(inImageData pages: [Data]) async throws -> String
}

struct TravelDocumentOCRService: TravelDocumentTextRecognizing {
    func recognizeText(inDocumentAt url: URL) async throws -> String {
        let hasSecurityScopedAccess = url.startAccessingSecurityScopedResource()
        defer {
            if hasSecurityScopedAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }

        let hasPDFExtension = url.pathExtension.lowercased() == "pdf"

        guard let documentData = try? Data(contentsOf: url) else {
            throw hasPDFExtension
                ? TravelDocumentOCRError.unreadablePDF
                : TravelDocumentOCRError.unreadableImage
        }

        if hasPDFExtension
            || documentData.starts(with: Data("%PDF".utf8)) {
            return try await recognizeText(inPDFData: documentData)
        }

        return try await recognizeText(inImageData: [documentData])
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

    private func recognizeText(inPDFData data: Data) async throws -> String {
        guard let document = PDFDocument(data: data),
              document.isLocked == false,
              document.pageCount > 0 else {
            throw TravelDocumentOCRError.unreadablePDF
        }

        var recognizedPages: [String] = []

        for index in 0..<document.pageCount {
            guard let page = document.page(at: index) else {
                throw TravelDocumentOCRError.unreadablePDF
            }

            let embeddedText = page.string?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

            if embeddedText.isEmpty == false {
                recognizedPages.append(embeddedText)
                continue
            }

            let pageImage = page.thumbnail(
                of: CGSize(width: 2_200, height: 2_200),
                for: .mediaBox
            )

            guard let pageData = pageImage.jpegData(compressionQuality: 0.9) else {
                throw TravelDocumentOCRError.unreadablePDF
            }

            do {
                let recognizedText = try await recognizeText(inImageData: [pageData])
                recognizedPages.append(recognizedText)
            } catch TravelDocumentOCRError.noRecognizedText {
                continue
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
