import CoreGraphics
import Foundation
import Vision

enum DetectionError: LocalizedError {
    case modelNotLoaded
    case detectionFailed(String)

    var errorDescription: String? {
        switch self {
        case .modelNotLoaded:
            "Damage detection model is not loaded. Add a DamageDetector.mlmodel to the project."
        case .detectionFailed(let reason):
            "Detection failed: \(reason)"
        }
    }
}

final class DamageDetectionService {
    private let modelService: CoreMLModelService
    private var request: VNCoreMLRequest?
    private let minimumDetectionConfidence: VNConfidence = 0.55
    private let duplicateBoxIoUThreshold = 0.45

    private(set) var mockMode = false

    init(modelService: CoreMLModelService = CoreMLModelService()) {
        self.modelService = modelService
    }

    func loadModel() async throws {
        do {
            try await modelService.loadModel()
        } catch {
            print("[Detection] Real model unavailable, enabling mock detection: \(error.localizedDescription)")
            mockMode = true
            return
        }

        let visionModel = try modelService.getVisionModel()
        let vnRequest = VNCoreMLRequest(model: visionModel) { _, _ in }
        vnRequest.imageCropAndScaleOption = .scaleFit
        request = vnRequest
    }

    func detectDamage(in image: CGImage) async throws -> [DetectionResult] {
        if mockMode {
            return generateMockDetections(for: image)
        }

        if !modelService.isModelLoaded {
            try await loadModel()
        }

        guard let request else {
            return generateMockDetections(for: image)
        }

        let handler = VNImageRequestHandler(cgImage: image, options: [:])

        do {
            try handler.perform([request])
        } catch {
            throw DetectionError.detectionFailed(error.localizedDescription)
        }

        guard let results = request.results as? [VNRecognizedObjectObservation] else {
            return []
        }

        let detections: [DetectionResult] = results.compactMap { observation in
            guard let topLabel = observation.labels.first else { return nil }
            guard topLabel.confidence >= minimumDetectionConfidence else { return nil }

            return DetectionResult(
                damageType: topLabel.identifier,
                confidence: Double(topLabel.confidence),
                boundingBox: observation.boundingBox
            )
        }

        return Self.removeDuplicateDetections(
            detections,
            iouThreshold: duplicateBoxIoUThreshold
        )
    }

    // MARK: - Improved Multi-Class Mock Detection

    private func generateMockDetections(for image: CGImage) -> [DetectionResult] {
        guard let grayscale = Self.toGrayscale(image),
              let rgbData = Self.toRGBData(image) else {
            print("[Detection] Mock mode — failed to preprocess image")
            return []
        }

        let width = grayscale.width
        let height = grayscale.height
        let grayPixels = grayscale.pixels

        var allDetections: [DetectionResult] = []

        // 1. Crack detection (multi-directional)
        let crackDetections = Self.detectCracks(grayPixels: grayPixels, width: width, height: height)
        allDetections.append(contentsOf: crackDetections)

        // 2. Surface damage detection (texture anomalies)
        let surfaceDetections = Self.detectSurfaceDamage(grayPixels: grayPixels, width: width, height: height)
        allDetections.append(contentsOf: surfaceDetections)

        // 3. Corrosion detection (color-based)
        let corrosionDetections = Self.detectCorrosion(rgbPixels: rgbData, grayPixels: grayPixels, width: width, height: height)
        allDetections.append(contentsOf: corrosionDetections)

        let filtered = allDetections.filter { $0.confidence >= Double(minimumDetectionConfidence) }
        let deduplicated = Self.removeDuplicateDetections(filtered, iouThreshold: 0.35)

        print("[Detection] Mock mode — \(deduplicated.count) detection(s): \(deduplicated.map { "\($0.damageType)(\(String(format: "%.0f", $0.confidence * 100))%)" }.joined(separator: ", "))")
        return deduplicated
    }

    // MARK: - Crack Detection (Multi-Directional)

    private static func detectCracks(grayPixels: [UInt8], width: Int, height: Int) -> [DetectionResult] {
        let edgeMap = Self.computeEdgeMap(grayPixels: grayPixels, width: width, height: height)
        let morphed = Self.morphologicalClose(edgeMap, width: width, height: height, radius: 1)

        let regions = Self.findConnectedRegions(morphed, width: width, height: height, minPixels: 12)

        return regions.compactMap { region -> DetectionResult? in
            let aspectRatio = Double(region.width) / max(Double(region.height), 1.0)
            let elongation = max(aspectRatio, 1.0 / max(aspectRatio, 0.001))

            guard elongation >= 1.8 else { return nil }

            let edgeDensity = Double(region.pixelCount) / max(Double(region.width * region.height), 1.0)
            guard edgeDensity >= 0.05 else { return nil }

            let bbox = Self.normalizeBBox(region: region, imageWidth: width, imageHeight: height)
            let confidence = Self.computeCrackConfidence(
                elongation: elongation,
                edgeDensity: edgeDensity,
                regionHeight: region.height,
                imageHeight: height
            )

            return DetectionResult(
                damageType: "Crack",
                confidence: confidence,
                boundingBox: bbox
            )
        }
    }

    private static func computeCrackConfidence(
        elongation: Double,
        edgeDensity: Double,
        regionHeight: Int,
        imageHeight: Int
    ) -> Double {
        let elongationScore = min(1.0, (elongation - 1.8) / 4.0)
        let densityScore = min(1.0, (edgeDensity - 0.05) / 0.25)
        let verticalSpan = Double(regionHeight) / Double(imageHeight)
        let spanScore = min(1.0, verticalSpan / 0.5)

        let raw = 0.30 * elongationScore + 0.35 * densityScore + 0.35 * spanScore + 0.45
        return min(0.97, max(0.55, raw))
    }

    // MARK: - Surface Damage Detection

    private static func detectSurfaceDamage(grayPixels: [UInt8], width: Int, height: Int) -> [DetectionResult] {
        let blockSize = 16
        var variances = [Double](repeating: 0, count: (width / blockSize) * (height / blockSize))
        var means = [Double](repeating: 0, count: variances.count)

        let blocksX = width / blockSize
        let blocksY = height / blockSize

        for by in 0..<blocksY {
            for bx in 0..<blocksX {
                let idx = by * blocksX + bx
                var sum = 0.0
                var sumSq = 0.0
                var count = 0

                for y in (by * blockSize)..<min((by + 1) * blockSize, height) {
                    for x in (bx * blockSize)..<min((bx + 1) * blockSize, width) {
                        let val = Double(grayPixels[y * width + x])
                        sum += val
                        sumSq += val * val
                        count += 1
                    }
                }

                let mean = sum / Double(count)
                means[idx] = mean
                variances[idx] = (sumSq / Double(count)) - (mean * mean)
            }
        }

        let globalMean = means.reduce(0, +) / Double(means.count)
        let globalVariance = variances.reduce(0, +) / Double(variances.count)
        let stdDev = sqrt(max(globalVariance, 1.0))

        var anomalyBlocks = [(bx: Int, by: Int, score: Double)]()

        for by in 0..<blocksY {
            for bx in 0..<blocksX {
                let idx = by * blocksX + bx
                let localVar = variances[idx]
                let localVarScore = localVar / (stdDev * stdDev + 1.0)

                let meanDiff = abs(means[idx] - globalMean) / (stdDev + 1.0)

                let combined = 0.6 * localVarScore + 0.4 * meanDiff

                if combined > 2.5 {
                    anomalyBlocks.append((bx: bx, by: by, score: combined))
                }
            }
        }

        let clusters = Self.clusterBlocks(anomalyBlocks, blocksX: blocksX, maxGap: 2)

        return clusters.compactMap { cluster -> DetectionResult? in
            guard cluster.blocks.count >= 3 else { return nil }

            let minX = cluster.blocks.map(\.bx).min()! * blockSize
            let maxX = (cluster.blocks.map(\.bx).max()! + 1) * blockSize
            let minY = cluster.blocks.map(\.by).min()! * blockSize
            let maxY = (cluster.blocks.map(\.by).max()! + 1) * blockSize

            let regionWidth = maxX - minX
            let regionHeight = maxY - minY
            guard regionWidth >= blockSize * 2, regionHeight >= blockSize * 2 else { return nil }

            let avgScore = cluster.blocks.map(\.score).reduce(0, +) / Double(cluster.blocks.count)
            let areaRatio = Double(cluster.blocks.count * blockSize * blockSize) / Double(width * height)
            guard areaRatio < 0.30 else { return nil }

            let confidence = Self.computeSurfaceDamageConfidence(
                avgAnomalyScore: avgScore,
                areaRatio: areaRatio,
                blockCount: cluster.blocks.count
            )

            let bbox = CGRect(
                x: Double(minX) / Double(width),
                y: 1.0 - Double(maxY) / Double(height) - Double(regionHeight) / Double(height),
                width: Double(regionWidth) / Double(width),
                height: Double(regionHeight) / Double(height)
            )

            let clamped = CGRect(
                x: max(0.01, min(bbox.origin.x, 0.98 - bbox.width)),
                y: max(0.01, min(bbox.origin.y, 0.98 - bbox.height)),
                width: min(bbox.width, 0.60),
                height: min(bbox.height, 0.60)
            )

            return DetectionResult(
                damageType: "Surface Damage",
                confidence: confidence,
                boundingBox: clamped
            )
        }
    }

    private static func computeSurfaceDamageConfidence(
        avgAnomalyScore: Double,
        areaRatio: Double,
        blockCount: Int
    ) -> Double {
        let anomalyNorm = min(1.0, (avgAnomalyScore - 2.5) / 5.0)
        let sizeScore = min(1.0, Double(blockCount) / 20.0)
        let raw = 0.50 * anomalyNorm + 0.30 * sizeScore + 0.40
        return min(0.95, max(0.55, raw))
    }

    // MARK: - Corrosion Detection (Color-Based)

    private static func detectCorrosion(
        rgbPixels: [UInt8],
        grayPixels: [UInt8],
        width: Int,
        height: Int
    ) -> [DetectionResult] {
        let blockSize = 12
        let blocksX = width / blockSize
        let blocksY = height / blockSize

        var corrosionBlocks = [(bx: Int, by: Int, score: Double)]()

        for by in 0..<blocksY {
            for bx in 0..<blocksX {
                var rustCount = 0
                var darkCount = 0
                var totalPixels = 0

                for y in (by * blockSize)..<min((by + 1) * blockSize, height) {
                    for x in (bx * blockSize)..<min((bx + 1) * blockSize, width) {
                        let rgbIdx = (y * width + x) * 3
                        let r = Double(rgbPixels[rgbIdx])
                        let g = Double(rgbPixels[rgbIdx + 1])
                        let b = Double(rgbPixels[rgbIdx + 2])

                        let gray = Double(grayPixels[y * width + x])

                        let isRusty = Self.isRustColor(r: r, g: g, b: b, gray: gray)
                        if isRusty { rustCount += 1 }

                        let isDark = gray < 80
                        if isDark { darkCount += 1 }

                        totalPixels += 1
                    }
                }

                let rustRatio = Double(rustCount) / Double(totalPixels)
                let darkRatio = Double(darkCount) / Double(totalPixels)

                if rustRatio > 0.15 && darkRatio > 0.20 {
                    let score = 0.6 * rustRatio + 0.4 * darkRatio
                    corrosionBlocks.append((bx: bx, by: by, score: score))
                }
            }
        }

        let clusters = Self.clusterBlocks(corrosionBlocks, blocksX: blocksX, maxGap: 2)

        return clusters.compactMap { cluster -> DetectionResult? in
            guard cluster.blocks.count >= 4 else { return nil }

            let minX = cluster.blocks.map(\.bx).min()! * blockSize
            let maxX = (cluster.blocks.map(\.bx).max()! + 1) * blockSize
            let minY = cluster.blocks.map(\.by).min()! * blockSize
            let maxY = (cluster.blocks.map(\.by).max()! + 1) * blockSize

            let regionWidth = maxX - minX
            let regionHeight = maxY - minY

            let avgScore = cluster.blocks.map(\.score).reduce(0, +) / Double(cluster.blocks.count)
            let areaRatio = Double(cluster.blocks.count * blockSize * blockSize) / Double(width * height)
            guard areaRatio < 0.25 else { return nil }

            let confidence = Self.computeCorrosionConfidence(
                avgRustScore: avgScore,
                areaRatio: areaRatio,
                blockCount: cluster.blocks.count
            )

            let bbox = CGRect(
                x: Double(minX) / Double(width),
                y: 1.0 - Double(maxY) / Double(height) - Double(regionHeight) / Double(height),
                width: Double(regionWidth) / Double(width),
                height: Double(regionHeight) / Double(height)
            )

            let clamped = CGRect(
                x: max(0.01, min(bbox.origin.x, 0.98 - bbox.width)),
                y: max(0.01, min(bbox.origin.y, 0.98 - bbox.height)),
                width: min(bbox.width, 0.50),
                height: min(bbox.height, 0.50)
            )

            return DetectionResult(
                damageType: "Corrosion",
                confidence: confidence,
                boundingBox: clamped
            )
        }
    }

    private static func isRustColor(r: Double, g: Double, b: Double, gray: Double) -> Bool {
        let maxC = max(r, g, b)
        let minC = min(r, g, b)
        let saturation = maxC > 0 ? (maxC - minC) / maxC : 0

        let reddish = r > g && r > b
        let warmTone = r > 100 && g < r * 0.85 && b < r * 0.65
        let brownish = r > 80 && g > 30 && g < r * 0.80 && b < g * 0.70

        return (reddish || warmTone || brownish) && saturation > 0.12 && gray < 180
    }

    private static func computeCorrosionConfidence(
        avgRustScore: Double,
        areaRatio: Double,
        blockCount: Int
    ) -> Double {
        let rustNorm = min(1.0, (avgRustScore - 0.15) / 0.40)
        let sizeScore = min(1.0, Double(blockCount) / 15.0)
        let raw = 0.55 * rustNorm + 0.30 * sizeScore + 0.40
        return min(0.96, max(0.55, raw))
    }

    // MARK: - Shared Computer Vision Primitives

    private struct GrayscaleImage {
        let pixels: [UInt8]
        let width: Int
        let height: Int
    }

    private static func toGrayscale(_ image: CGImage) -> GrayscaleImage? {
        let maxW = 480
        let scale = Double(image.width) > Double(maxW) ? Double(maxW) / Double(image.width) : 1.0
        let w = max(1, Int(Double(image.width) * scale))
        let h = max(1, Int(Double(image.height) * scale))

        let colorSpace = CGColorSpaceCreateDeviceGray()
        guard let ctx = CGContext(
            data: nil,
            width: w,
            height: h,
            bitsPerComponent: 8,
            bytesPerRow: w,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else { return nil }

        ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
        guard let data = ctx.data else { return nil }
        let pixels = Array(UnsafeBufferPointer(
            start: data.assumingMemoryBound(to: UInt8.self),
            count: w * h
        ))
        return GrayscaleImage(pixels: pixels, width: w, height: h)
    }

    private static func toRGBData(_ image: CGImage) -> [UInt8]? {
        let maxW = 480
        let scale = Double(image.width) > Double(maxW) ? Double(maxW) / Double(image.width) : 1.0
        let w = max(1, Int(Double(image.width) * scale))
        let h = max(1, Int(Double(image.height) * scale))

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bytesPerRow = w * 3
        guard let ctx = CGContext(
            data: nil,
            width: w,
            height: h,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else { return nil }

        ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
        guard let data = ctx.data else { return nil }
        return Array(UnsafeBufferPointer(
            start: data.assumingMemoryBound(to: UInt8.self),
            count: bytesPerRow * h
        ))
    }

    private static func computeEdgeMap(grayPixels: [UInt8], width: Int, height: Int) -> [Bool] {
        var edges = [Bool](repeating: false, count: width * height)

        for y in 1..<(height - 1) {
            for x in 1..<(width - 1) {
                let idx = y * width + x

                let gx = -Double(grayPixels[(y - 1) * width + (x - 1)])
                    - 2.0 * Double(grayPixels[y * width + (x - 1)])
                    - Double(grayPixels[(y + 1) * width + (x - 1)])
                    + Double(grayPixels[(y - 1) * width + (x + 1)])
                    + 2.0 * Double(grayPixels[y * width + (x + 1)])
                    + Double(grayPixels[(y + 1) * width + (x + 1)])

                let gy = -Double(grayPixels[(y - 1) * width + (x - 1)])
                    - 2.0 * Double(grayPixels[(y - 1) * width + x])
                    - Double(grayPixels[(y - 1) * width + (x + 1)])
                    + Double(grayPixels[(y + 1) * width + (x - 1)])
                    + 2.0 * Double(grayPixels[(y + 1) * width + x])
                    + Double(grayPixels[(y + 1) * width + (x + 1)])

                let magnitude = sqrt(gx * gx + gy * gy)
                edges[idx] = magnitude > 40.0
            }
        }
        return edges
    }

    private static func morphologicalClose(_ input: [Bool], width: Int, height: Int, radius: Int) -> [Bool] {
        let dilated = dilate(input, width: width, height: height, radius: radius)
        return erode(dilated, width: width, height: height, radius: radius)
    }

    private static func dilate(_ input: [Bool], width: Int, height: Int, radius: Int) -> [Bool] {
        var output = [Bool](repeating: false, count: width * height)
        for y in 0..<height {
            for x in 0..<width {
                var found = false
                for dy in -radius...radius {
                    for dx in -radius...radius {
                        let ny = y + dy, nx = x + dx
                        if ny >= 0 && ny < height && nx >= 0 && nx < width && input[ny * width + nx] {
                            found = true
                            break
                        }
                    }
                    if found { break }
                }
                output[y * width + x] = found
            }
        }
        return output
    }

    private static func erode(_ input: [Bool], width: Int, height: Int, radius: Int) -> [Bool] {
        var output = [Bool](repeating: false, count: width * height)
        for y in 0..<height {
            for x in 0..<width {
                var allSet = true
                for dy in -radius...radius {
                    for dx in -radius...radius {
                        let ny = y + dy, nx = x + dx
                        if ny < 0 || ny >= height || nx < 0 || nx >= width || !input[ny * width + nx] {
                            allSet = false
                            break
                        }
                    }
                    if !allSet { break }
                }
                output[y * width + x] = allSet
            }
        }
        return output
    }

    private struct Region {
        var minX: Int
        var maxX: Int
        var minY: Int
        var maxY: Int
        var pixelCount: Int

        var width: Int {
            maxX - minX + 1
        }

        var height: Int {
            maxY - minY + 1
        }
    }

    private static func findConnectedRegions(_ binary: [Bool], width: Int, height: Int, minPixels: Int) -> [Region] {
        var visited = [Bool](repeating: false, count: width * height)
        var regions: [Region] = []

        for startY in 0..<height {
            for startX in 0..<width {
                let idx = startY * width + startX
                if binary[idx] && !visited[idx] {
                    var stack = [startX, startY]
                    visited[idx] = true
                    var region = Region(minX: startX, maxX: startX, minY: startY, maxY: startY, pixelCount: 0)

                    while stack.count >= 2 {
                        let y = stack.removeLast()
                        let x = stack.removeLast()
                        region.pixelCount += 1
                        region.minX = min(region.minX, x)
                        region.maxX = max(region.maxX, x)
                        region.minY = min(region.minY, y)
                        region.maxY = max(region.maxY, y)

                        for (dx, dy) in [(-1,0),(1,0),(0,-1),(0,1)] {
                            let nx = x + dx, ny = y + dy
                            if nx >= 0 && nx < width && ny >= 0 && ny < height {
                                let nIdx = ny * width + nx
                                if binary[nIdx] && !visited[nIdx] {
                                    visited[nIdx] = true
                                    stack.append(contentsOf: [nx, ny])
                                }
                            }
                        }
                    }

                    if region.pixelCount >= minPixels {
                        regions.append(region)
                    }
                }
            }
        }
        return regions
    }

    private static func normalizeBBox(region: Region, imageWidth: Int, imageHeight: Int) -> CGRect {
        let x = Double(region.minX) / Double(imageWidth)
        let w = Double(region.maxX - region.minX + 1) / Double(imageWidth)
        let h = Double(region.maxY - region.minY + 1) / Double(imageHeight)
        let yBottom = 1.0 - Double(region.maxY) / Double(imageHeight) - h

        return CGRect(
            x: max(0.01, min(x, 0.98 - w)),
            y: max(0.01, min(yBottom, 0.98 - h)),
            width: min(w, 0.80),
            height: min(h, 0.80)
        )
    }

    private struct BlockCluster {
        let blocks: [(bx: Int, by: Int, score: Double)]
    }

    private static func clusterBlocks(
        _ blocks: [(bx: Int, by: Int, score: Double)],
        blocksX: Int,
        maxGap: Int
    ) -> [BlockCluster] {
        guard !blocks.isEmpty else { return [] }

        let sorted = blocks.sorted { $0.by * blocksX + $0.bx < $1.by * blocksX + $1.bx }
        var visited = [Bool](repeating: false, count: sorted.count)
        var clusters: [BlockCluster] = []

        for i in 0..<sorted.count {
            if visited[i] { continue }
            var cluster = [sorted[i]]
            visited[i] = true
            var queue = [i]

            while !queue.isEmpty {
                let current = queue.removeFirst()
                for j in 0..<sorted.count where !visited[j] {
                    let dx = abs(sorted[current].bx - sorted[j].bx)
                    let dy = abs(sorted[current].by - sorted[j].by)
                    if dx <= maxGap && dy <= maxGap {
                        visited[j] = true
                        cluster.append(sorted[j])
                        queue.append(j)
                    }
                }
            }

            clusters.append(BlockCluster(blocks: cluster))
        }

        return clusters
    }

    // MARK: - NMS

    static func removeDuplicateDetections(
        _ detections: [DetectionResult],
        iouThreshold: Double
    ) -> [DetectionResult] {
        detections
            .sorted { $0.confidence > $1.confidence }
            .reduce(into: [DetectionResult]()) { keptDetections, detection in
                let duplicatesExistingDetection = keptDetections.contains { keptDetection in
                    keptDetection.damageType == detection.damageType &&
                    intersectionOverUnion(keptDetection.boundingBox, detection.boundingBox) >= iouThreshold
                }

                if !duplicatesExistingDetection {
                    keptDetections.append(detection)
                }
            }
    }

    static func intersectionOverUnion(_ first: CGRect, _ second: CGRect) -> Double {
        let intersection = first.intersection(second)
        guard !intersection.isNull else { return 0 }

        let intersectionArea = intersection.width * intersection.height
        let unionArea = first.width * first.height + second.width * second.height - intersectionArea
        guard unionArea > 0 else { return 0 }

        return Double(intersectionArea / unionArea)
    }
}
