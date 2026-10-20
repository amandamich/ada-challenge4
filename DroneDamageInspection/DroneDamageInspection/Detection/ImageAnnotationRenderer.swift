import CoreGraphics
import CoreText
import Foundation

enum ImageAnnotationRenderer {
    static func renderDetections(
        on image: CGImage,
        detections: [DetectionResult]
    ) -> CGImage? {
        guard !detections.isEmpty else { return image }

        let width = image.width
        let height = image.height
        let colorSpace = CGColorSpaceCreateDeviceRGB()

        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return image }

        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

        for detection in detections {
            let box = detection.boundingBox
            let rect = CGRect(
                x: box.origin.x * CGFloat(width),
                y: (1 - box.origin.y - box.height) * CGFloat(height),
                width: box.width * CGFloat(width),
                height: box.height * CGFloat(height)
            )

            drawBoundingBox(context: context, rect: rect, detection: detection, imageWidth: width, imageHeight: height)
        }

        return context.makeImage()
    }

    private static func drawBoundingBox(
        context: CGContext,
        rect: CGRect,
        detection: DetectionResult,
        imageWidth: Int,
        imageHeight: Int
    ) {
        let strokeWidth: CGFloat = max(2.0, min(CGFloat(imageWidth), CGFloat(imageHeight)) * 0.004)
        let fontSize: CGFloat = max(12.0, min(CGFloat(imageWidth), CGFloat(imageHeight)) * 0.03)
        let padding: CGFloat = max(4.0, fontSize * 0.3)

        let confidence = Int(detection.confidence * 100)

        let buildingPosition = buildingPositionDescription(
            for: rect,
            imageWidth: CGFloat(imageWidth),
            imageHeight: CGFloat(imageHeight)
        )
        let labelText = "\(detection.damageType) \(confidence)% - \(buildingPosition)"

        let redColor = CGColor(red: 1.0, green: 0.2, blue: 0.2, alpha: 1.0)
        let bgColor = CGColor(red: 1.0, green: 0.2, blue: 0.2, alpha: 0.85)

        context.setStrokeColor(redColor)
        context.setLineWidth(strokeWidth)
        context.stroke(rect)

        let labelFont = CTFontCreateWithName("Helvetica-Bold" as CFString, fontSize, nil)
        let attributedLabel = NSAttributedString(
            string: labelText,
            attributes: [
                kCTFontAttributeName as NSAttributedString.Key: labelFont,
                kCTForegroundColorAttributeName as NSAttributedString.Key: CGColor(red: 1, green: 1, blue: 1, alpha: 1)
            ]
        )

        let framesetter = CTFramesetterCreateWithAttributedString(attributedLabel)
        let labelSize = CTFramesetterSuggestFrameSizeWithConstraints(
            framesetter,
            CFRangeMake(0, attributedLabel.length),
            nil,
            CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude),
            nil
        )

        let labelHeight = labelSize.height + padding * 2
        let maxLabelWidth = max(padding * 2, CGFloat(imageWidth) - padding * 2)
        let labelWidth = min(labelSize.width + padding * 2, maxLabelWidth)
        let preferredLabelY = rect.origin.y - labelHeight
        let labelY: CGFloat
        if preferredLabelY >= padding {
            labelY = preferredLabelY
        } else if rect.maxY + labelHeight + padding <= CGFloat(imageHeight) {
            labelY = rect.maxY
        } else {
            labelY = min(max(rect.origin.y, padding), CGFloat(imageHeight) - labelHeight - padding)
        }

        let labelRect = CGRect(
            x: min(max(rect.origin.x, padding), CGFloat(imageWidth) - labelWidth - padding),
            y: labelY,
            width: labelWidth,
            height: labelHeight
        )

        context.setFillColor(bgColor)
        context.fill(labelRect)

        let line = CTLineCreateWithAttributedString(attributedLabel)
        let ellipsis = CTLineCreateWithAttributedString(NSAttributedString(
            string: "...",
            attributes: [
                kCTFontAttributeName as NSAttributedString.Key: labelFont,
                kCTForegroundColorAttributeName as NSAttributedString.Key: CGColor(red: 1, green: 1, blue: 1, alpha: 1)
            ]
        ))
        let visibleLine = CTLineCreateTruncatedLine(
            line,
            Double(max(1, labelRect.width - padding * 2)),
            .end,
            ellipsis
        ) ?? line

        context.saveGState()
        context.textMatrix = .identity
        context.textPosition = CGPoint(
            x: labelRect.origin.x + padding,
            y: labelRect.origin.y + padding + fontSize * 0.85
        )
        CTLineDraw(visibleLine, context)

        context.restoreGState()
    }

    private static func buildingPositionDescription(
        for rect: CGRect,
        imageWidth: CGFloat,
        imageHeight: CGFloat
    ) -> String {
        let centerX = rect.midX / imageWidth
        let centerY = rect.midY / imageHeight
        let horizontalZone = zone(
            value: centerX,
            lowerLabel: "kiri",
            middleLabel: "tengah",
            upperLabel: "kanan"
        )
        let verticalZone = zone(
            value: centerY,
            lowerLabel: "atas",
            middleLabel: "tengah",
            upperLabel: "bawah"
        )

        let minXPercent = Int((rect.minX / imageWidth * 100).rounded())
        let maxXPercent = Int((rect.maxX / imageWidth * 100).rounded())
        let minYPercent = Int((rect.minY / imageHeight * 100).rounded())
        let maxYPercent = Int((rect.maxY / imageHeight * 100).rounded())

        return "Gedung: \(verticalZone)-\(horizontalZone) x \(minXPercent)-\(maxXPercent)% y \(minYPercent)-\(maxYPercent)%"
    }

    private static func zone(
        value: CGFloat,
        lowerLabel: String,
        middleLabel: String,
        upperLabel: String
    ) -> String {
        if value < 1.0 / 3.0 {
            return lowerLabel
        } else if value < 2.0 / 3.0 {
            return middleLabel
        } else {
            return upperLabel
        }
    }
}
