//
//  TravelDocumentSourceService.swift
//  TripFlow
//
//  Created by Codex on 21.07.26.
//

import Foundation
import UIKit

enum TravelDocumentSourceError: Error, Equatable {
    case unreadableFile
    case unreadableScanPage
    case previewUnavailable
    case sourceTooLarge(maximumByteCount: Int)
    case tooManyScanPages(maximumPageCount: Int)
}

protocol TravelDocumentSourcePreparing {
    func validateDocument(at url: URL) throws
    func validateScannedPages(_ pages: [Data]) throws
    func data(from url: URL) throws -> Data
    func pdfData(fromScannedPages pages: [Data]) throws -> Data
}

protocol TravelDocumentSourcePreviewing {
    func temporaryPreviewURL(for data: Data, fileName: String) throws -> URL
    func removeTemporaryPreview(at url: URL)
}

struct TravelDocumentSourceService: TravelDocumentSourcePreparing, TravelDocumentSourcePreviewing {
    static let defaultMaximumSourceByteCount = 25 * 1_024 * 1_024
    static let defaultMaximumScanPageCount = 20

    private let maximumSourceByteCount: Int
    private let maximumScanPageCount: Int

    init(
        maximumSourceByteCount: Int = Self.defaultMaximumSourceByteCount,
        maximumScanPageCount: Int = Self.defaultMaximumScanPageCount
    ) {
        self.maximumSourceByteCount = maximumSourceByteCount
        self.maximumScanPageCount = maximumScanPageCount
    }

    func validateDocument(at url: URL) throws {
        let hasSecurityScopedAccess = url.startAccessingSecurityScopedResource()
        defer {
            if hasSecurityScopedAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }

        guard let fileSize = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize else {
            return
        }

        try validateSourceByteCount(fileSize)
    }

    func validateScannedPages(_ pages: [Data]) throws {
        guard pages.count <= maximumScanPageCount else {
            throw TravelDocumentSourceError.tooManyScanPages(
                maximumPageCount: maximumScanPageCount
            )
        }

        var totalByteCount = 0

        for page in pages {
            guard page.count <= maximumSourceByteCount - totalByteCount else {
                throw TravelDocumentSourceError.sourceTooLarge(
                    maximumByteCount: maximumSourceByteCount
                )
            }

            totalByteCount += page.count
        }
    }

    func data(from url: URL) throws -> Data {
        let hasSecurityScopedAccess = url.startAccessingSecurityScopedResource()
        defer {
            if hasSecurityScopedAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }

        let sourceData: Data

        do {
            sourceData = try Data(contentsOf: url, options: .mappedIfSafe)
        } catch {
            throw TravelDocumentSourceError.unreadableFile
        }

        try validateSourceByteCount(sourceData.count)
        return sourceData
    }

    func pdfData(fromScannedPages pages: [Data]) throws -> Data {
        try validateScannedPages(pages)

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

        let pdfData = renderer.pdfData { context in
            for image in images {
                context.beginPage()
                image.draw(in: aspectFitRect(for: image.size, inside: contentBounds))
            }
        }

        try validateSourceByteCount(pdfData.count)
        return pdfData
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

    private func validateSourceByteCount(_ byteCount: Int) throws {
        guard byteCount <= maximumSourceByteCount else {
            throw TravelDocumentSourceError.sourceTooLarge(
                maximumByteCount: maximumSourceByteCount
            )
        }
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
