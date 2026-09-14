import UIKit
import CoreGraphics

struct ScreenshotStitcher {
    enum StitchError: LocalizedError {
        case notEnoughImages
        case invalidImage
        case noUsableOverlap(Int)

        var errorDescription: String? {
            switch self {
            case .notEnoughImages:
                return "Choose at least two screenshots."
            case .invalidImage:
                return "One of the screenshots could not be processed."
            case .noUsableOverlap(let index):
                return "I couldn’t confidently match screenshot \(index) to the previous one. Try screenshots with a little more overlap."
            }
        }
    }

    struct Match {
        let currentStartY: Int
        let overlapHeight: Int
        let score: Double
    }

    func stitch(images: [UIImage]) throws -> UIImage {
        guard images.count >= 2 else { throw StitchError.notEnoughImages }
        guard let firstCG = images[0].cgImage else { throw StitchError.invalidImage }

        let targetWidth = firstCG.width
        let normalized = try images.map { try normalizedImage($0, targetWidth: targetWidth) }

        var segments: [(image: UIImage, cropTop: Int)] = [(normalized[0], 0)]
        var previous = normalized[0]

        for index in 1..<normalized.count {
            let current = normalized[index]
            let match = try bestMatch(previous: previous, current: current, imageIndex: index + 1)
            let cropTop = match.currentStartY + match.overlapHeight
            if cropTop >= Int(current.size.height * current.scale) - 8 {
                throw StitchError.noUsableOverlap(index + 1)
            }
            segments.append((current, cropTop))
            previous = current
        }

        return try render(segments: segments, widthPixels: targetWidth)
    }

    private func normalizedImage(_ image: UIImage, targetWidth: Int) throws -> UIImage {
        guard let cg = image.cgImage else { throw StitchError.invalidImage }
        if cg.width == targetWidth { return image }

        let scale = CGFloat(targetWidth) / CGFloat(cg.width)
        let targetSize = CGSize(width: CGFloat(targetWidth), height: CGFloat(cg.height) * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }

    private func bestMatch(previous: UIImage, current: UIImage, imageIndex: Int) throws -> Match {
        guard let prevCG = previous.cgImage,
              let currCG = current.cgImage else { throw StitchError.invalidImage }

        let sampleWidth = 120
        let prev = try GrayImage(cgImage: prevCG, targetWidth: sampleWidth)
        let curr = try GrayImage(cgImage: currCG, targetWidth: sampleWidth)

        let minOverlap = max(40, Int(Double(min(prev.height, curr.height)) * 0.14))
        let maxOverlap = Int(Double(min(prev.height, curr.height)) * 0.72)
        let maxHeaderSkip = Int(Double(curr.height) * 0.22)
        let xInset = max(4, Int(Double(sampleWidth) * 0.08))

        var best: Match?
        var bestSample: (start: Int, overlap: Int, score: Double)?

        let overlapStep = max(2, (maxOverlap - minOverlap) / 90)
        let startStep = max(1, maxHeaderSkip / 28)

        for currentStart in stride(from: 0, through: maxHeaderSkip, by: startStep) {
            let possibleMax = min(maxOverlap, curr.height - currentStart - 1)
            guard possibleMax >= minOverlap else { continue }

            for overlap in stride(from: minOverlap, through: possibleMax, by: overlapStep) {
                let prevStart = prev.height - overlap
                let score = meanAbsoluteDifference(
                    a: prev,
                    aY: prevStart,
                    b: curr,
                    bY: currentStart,
                    height: overlap,
                    xInset: xInset
                )
                if bestSample == nil || score < bestSample!.score {
                    bestSample = (currentStart, overlap, score)
                }
            }
        }

        guard let coarse = bestSample else { throw StitchError.invalidImage }

        let startRange = max(0, coarse.start - startStep)...min(maxHeaderSkip, coarse.start + startStep)
        let overlapRange = max(minOverlap, coarse.overlap - overlapStep * 2)...min(maxOverlap, coarse.overlap + overlapStep * 2)

        for currentStart in startRange {
            for overlap in overlapRange where currentStart + overlap < curr.height {
                let prevStart = prev.height - overlap
                guard prevStart >= 0 else { continue }
                let score = meanAbsoluteDifference(
                    a: prev,
                    aY: prevStart,
                    b: curr,
                    bY: currentStart,
                    height: overlap,
                    xInset: xInset
                )
                let candidate = Match(
                    currentStartY: currentStart,
                    overlapHeight: overlap,
                    score: score
                )
                if best == nil || candidate.score < best!.score {
                    best = candidate
                }
            }
        }

        guard let sampleMatch = best else { throw StitchError.invalidImage }
        guard sampleMatch.score < 22.0 else { throw StitchError.noUsableOverlap(imageIndex) }

        let prevScaleY = Double(prevCG.height) / Double(prev.height)
        let currScaleY = Double(currCG.height) / Double(curr.height)
        let startPixels = Int((Double(sampleMatch.currentStartY) * currScaleY).rounded())
        let overlapPixels = Int((Double(sampleMatch.overlapHeight) * min(prevScaleY, currScaleY)).rounded())

        return Match(
            currentStartY: startPixels,
            overlapHeight: overlapPixels,
            score: sampleMatch.score
        )
    }

    private func meanAbsoluteDifference(
        a: GrayImage,
        aY: Int,
        b: GrayImage,
        bY: Int,
        height: Int,
        xInset: Int
    ) -> Double {
        let usableWidth = a.width - 2 * xInset
        guard usableWidth > 4, height > 2 else { return .greatestFiniteMagnitude }

        var total: Int64 = 0
        var count: Int64 = 0

        for y in stride(from: 0, to: height, by: 2) {
            let aRow = (aY + y) * a.width
            let bRow = (bY + y) * b.width
            for x in stride(from: xInset, to: a.width - xInset, by: 2) {
                total += Int64(abs(Int(a.pixels[aRow + x]) - Int(b.pixels[bRow + x])))
                count += 1
            }
        }

        return count == 0 ? .greatestFiniteMagnitude : Double(total) / Double(count)
    }

    private func render(segments: [(image: UIImage, cropTop: Int)], widthPixels: Int) throws -> UIImage {
        var totalHeight = 0
        var cgSegments: [(CGImage, Int)] = []

        for segment in segments {
            guard let cg = segment.image.cgImage else { throw StitchError.invalidImage }
            let cropTop = min(max(0, segment.cropTop), cg.height)
            totalHeight += cg.height - cropTop
            cgSegments.append((cg, cropTop))
        }

        guard totalHeight > 0 else { throw StitchError.invalidImage }

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(
            size: CGSize(width: CGFloat(widthPixels), height: CGFloat(totalHeight)),
            format: format
        )

        return renderer.image { context in
            UIColor.black.setFill()
            context.cgContext.fill(
                CGRect(x: 0, y: 0, width: CGFloat(widthPixels), height: CGFloat(totalHeight))
            )

            var y: CGFloat = 0
            for (cg, cropTop) in cgSegments {
                let cropRect = CGRect(
                    x: 0,
                    y: CGFloat(cropTop),
                    width: CGFloat(cg.width),
                    height: CGFloat(cg.height - cropTop)
                )
                guard let cropped = cg.cropping(to: cropRect) else { continue }
                let height = CGFloat(cropped.height)
                UIImage(cgImage: cropped).draw(
                    in: CGRect(x: 0, y: y, width: CGFloat(widthPixels), height: height)
                )
                y += height
            }
        }
    }
}

private struct GrayImage {
    let width: Int
    let height: Int
    let pixels: [UInt8]

    init(cgImage: CGImage, targetWidth: Int) throws {
        let scale = Double(targetWidth) / Double(cgImage.width)
        let targetHeight = max(1, Int((Double(cgImage.height) * scale).rounded()))
        var data = [UInt8](repeating: 0, count: targetWidth * targetHeight)

        let drew = data.withUnsafeMutableBytes { rawBuffer -> Bool in
            guard let base = rawBuffer.baseAddress,
                  let context = CGContext(
                    data: base,
                    width: targetWidth,
                    height: targetHeight,
                    bitsPerComponent: 8,
                    bytesPerRow: targetWidth,
                    space: CGColorSpaceCreateDeviceGray(),
                    bitmapInfo: CGImageAlphaInfo.none.rawValue
                  ) else {
                return false
            }

            context.interpolationQuality = .medium
            context.draw(
                cgImage,
                in: CGRect(x: 0, y: 0, width: CGFloat(targetWidth), height: CGFloat(targetHeight))
            )
            return true
        }

        guard drew else { throw ScreenshotStitcher.StitchError.invalidImage }
        self.width = targetWidth
        self.height = targetHeight
        self.pixels = data
    }
}
