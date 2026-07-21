//
//  TravelDocumentSourceService.swift
//  TripFlow
//
//  Created by Codex on 21.07.26.
//

import Foundation
import UIKit

enum TravelDocumentSourceError: Error {
    case unreadableFile
    case unreadableScanPage
    case previewUnavailable
}

protocol TravelDocumentSourcePreparing {
    func data(from url: URL) throws -> Data
    func pdfData(fromScannedPages pages: [Data]) throws -> Data
}

protocol TravelDocumentSourcePreviewing {
    func temporaryPreviewURL(for data: Data, fileName: String) throws -> URL
    func removeTemporaryPreview(at url: URL)
}

struct TravelDocumentSourceService: TravelDocumentSourcePreparing, TravelDocumentSourcePreviewing {
    func data(from url: URL) throws -> Data {
        let hasSecurityScopedAccess = url.startAccessingSecurityScopedResource()
        defer {
            if hasSecurityScopedAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }

        do {
            return try Data(contentsOf: url, options: .mappedIfSafe)
        } catch {
            throw TravelDocumentSourceError.unreadableFile
        }
    }

    func pdfData(fromScannedPages pages: [Data]) throws -> Data {
        let images = try pages.map { pageData in
            guard let image = UIImage(data: pageData),
                  image.size.width > 0,
                  image.size.height > 0 else {
                throw TravelDocumentSourceError.unreadableScanPage
            }

            return image
        }

        guard images.isEmpty == false else {
            throw TravelDocumentSourceError.unreadableScanPage
        }

        let pageBounds = CGRect(x: 0, y: 0, width: 595, height: 842)
        let contentBounds = pageBounds.insetBy(dx: 24, dy: 24)
        let renderer = UIGraphicsPDFRenderer(bounds: pageBounds)

        return renderer.pdfData { context in
            for image in images {
                context.beginPage()
                image.draw(in: aspectFitRect(for: image.size, inside: contentBounds))
            }
        }
    }

    func temporaryPreviewURL(for data: Data, fileName: String) throws -> URL {
        guard data.isEmpty == false else {
            throw TravelDocumentSourceError.previewUnavailable
        }

        let previewDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("TripFlowPreviews", isDirectory: true)
        let sourceFileName = URL(fileURLWithPath: fileName).lastPathComponent
        let previewFileName = sourceFileName.isEmpty ? "Reiseunterlage" : sourceFileName
        let previewURL = previewDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(URL(fileURLWithPath: previewFileName).pathExtension)

        do {
            try FileManager.default.createDirectory(
                at: previewDirectory,
                withIntermediateDirectories: true
            )
            try data.write(to: previewURL, options: .atomic)
            return previewURL
        } catch {
            throw TravelDocumentSourceError.previewUnavailable
        }
    }

    func removeTemporaryPreview(at url: URL) {
        try? FileManager.default.removeItem(at: url)
    }

    private func aspectFitRect(for imageSize: CGSize, inside bounds: CGRect) -> CGRect {
        let scale = min(
            bounds.width / imageSize.width,
            bounds.height / imageSize.height
        )
        let fittedSize = CGSize(
            width: imageSize.width * scale,
            height: imageSize.height * scale
        )

        return CGRect(
            x: bounds.midX - fittedSize.width / 2,
            y: bounds.midY - fittedSize.height / 2,
            width: fittedSize.width,
            height: fittedSize.height
        )
    }
}
