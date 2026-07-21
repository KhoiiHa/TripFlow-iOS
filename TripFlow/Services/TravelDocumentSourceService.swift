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
}

protocol TravelDocumentSourcePreparing {
    func data(from url: URL) throws -> Data
    func pdfData(fromScannedPages pages: [Data]) throws -> Data
}

struct TravelDocumentSourceService: TravelDocumentSourcePreparing {
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
