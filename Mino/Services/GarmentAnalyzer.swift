import CoreImage
import CoreML
import MinoKit
import UIKit
import Vision

/// What Mino understood from a photo. Everything runs on device with Apple Vision.
struct GarmentAnalysis: Sendable {
    /// Background-free PNG when the subject could be lifted, the plain photo otherwise.
    let photo: Data
    /// Most likely categories first; empty when neither the classifier nor the outline has an idea.
    let categories: [GarmentCategory]
    /// The classifier itself named the garment; otherwise the categories come from its outline only.
    let isRecognized: Bool
    let color: GarmentColor?
    /// Text read on the photo (a visible label often carries the size).
    let texts: [String]
}

enum GarmentAnalyzer {
    static func analyze(_ image: UIImage) async -> GarmentAnalysis {
        await Task.detached(priority: .userInitiated) {
            let upright = redraw(image, maxDimension: 1024)
            guard let cgImage = upright.cgImage else {
                return GarmentAnalysis(photo: upright.pngData() ?? Data(), categories: [], isRecognized: false, color: nil, texts: [])
            }
            let cutout = liftSubject(from: cgImage)
            let stored = redraw(UIImage(cgImage: cutout ?? cgImage), maxDimension: 600)
            // The garment alone on white reads better than the photo with its background.
            let sheet = cutout.flatMap { onWhite($0) } ?? cgImage
            let labels = classify(sheet)
            let families = recognizeFamily(in: sheet)
            let shape = cutout.flatMap { outline(of: $0) }
            #if DEBUG
            // What Apple's classifier saw, to tune Mino's keywords from the Xcode console.
            print("Mino recognition:", shape?.family as Any, families.prefix(3).map { "\($0.identifier) \(Int($0.confidence * 100))%" }, labels.prefix(8).map { "\($0.identifier) \(Int($0.confidence * 100))%" })
            #endif
            return GarmentAnalysis(
                photo: stored.pngData() ?? Data(),
                categories: CategoryGuess.ranked(fromLabels: labels, shape: shape, families: families),
                isRecognized: (families.first?.confidence ?? 0) >= 0.5 || !CategoryGuess.ranked(fromLabels: labels).isEmpty,
                color: dominantColor(of: cutout ?? cgImage, isCutout: cutout != nil),
                texts: recognizeText(in: cgImage)
            )
        }.value
    }

    /// Reads a care label photographed on its own.
    static func readLabel(_ image: UIImage) async -> [String] {
        await Task.detached(priority: .userInitiated) {
            guard let cgImage = redraw(image, maxDimension: 1600).cgImage else { return [] }
            return recognizeText(in: cgImage)
        }.value
    }

    // MARK: Vision

    private static func liftSubject(from image: CGImage) -> CGImage? {
        let request = VNGenerateForegroundInstanceMaskRequest()
        let handler = VNImageRequestHandler(cgImage: image)
        guard (try? handler.perform([request])) != nil,
              let observation = request.results?.first,
              let buffer = try? observation.generateMaskedImage(
                  ofInstances: observation.allInstances, from: handler, croppedToInstancesExtent: true
              ) else { return nil }
        let ciImage = CIImage(cvPixelBuffer: buffer)
        return CIContext().createCGImage(ciImage, from: ciImage.extent)
    }

    private static func classify(_ image: CGImage) -> [(identifier: String, confidence: Float)] {
        let request = VNClassifyImageRequest()
        guard (try? VNImageRequestHandler(cgImage: image).perform([request])) != nil else { return [] }
        return Array((request.results ?? []).prefix(20).map { (identifier: $0.identifier, confidence: $0.confidence) })
    }

    /// Mino's own classifier, trained on children's garment families (see design/classifier).
    private static let familyModel: VNCoreMLModel? = {
        guard let url = Bundle.main.url(forResource: "MinoGarmentClassifier", withExtension: "mlmodelc"),
              let model = try? MLModel(contentsOf: url) else { return nil }
        return try? VNCoreMLModel(for: model)
    }()

    private static func recognizeFamily(in image: CGImage) -> [(identifier: String, confidence: Float)] {
        guard let model = familyModel else { return [] }
        let request = VNCoreMLRequest(model: model)
        // Trained on whole garments squeezed to a square, like this.
        request.imageCropAndScaleOption = .scaleFill
        guard (try? VNImageRequestHandler(cgImage: image).perform([request])) != nil else { return [] }
        let results = (request.results as? [VNClassificationObservation]) ?? []
        return results.prefix(3).map { (identifier: $0.identifier, confidence: $0.confidence) }
    }

    private static func recognizeText(in image: CGImage) -> [String] {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false
        guard (try? VNImageRequestHandler(cgImage: image).perform([request])) != nil else { return [] }
        return (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }
    }

    // MARK: Pixels

    /// Samples a small thumbnail. On a cut-out, only opaque pixels count; on a plain photo,
    /// only the central area, where the garment usually is.
    private static func dominantColor(of image: CGImage, isCutout: Bool) -> GarmentColor? {
        let side = 32
        var pixels = [UInt8](repeating: 0, count: side * side * 4)
        let drawn = pixels.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(
                data: buffer.baseAddress, width: side, height: side, bitsPerComponent: 8, bytesPerRow: side * 4,
                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return false }
            context.draw(image, in: CGRect(x: 0, y: 0, width: side, height: side))
            return true
        }
        guard drawn else { return nil }
        var samples: [RGBColor] = []
        for y in 0..<side {
            for x in 0..<side {
                if !isCutout && (x < side / 5 || x >= side * 4 / 5 || y < side / 5 || y >= side * 4 / 5) { continue }
                let offset = (y * side + x) * 4
                let alpha = Double(pixels[offset + 3]) / 255
                guard alpha > 0.8 else { continue }
                samples.append(RGBColor(
                    red: Double(pixels[offset]) / 255 / alpha,
                    green: Double(pixels[offset + 1]) / 255 / alpha,
                    blue: Double(pixels[offset + 2]) / 255 / alpha
                ))
            }
        }
        return GarmentColor.dominant(in: samples)
    }

    /// The cut-out on a white sheet, as a catalogue photo.
    private static func onWhite(_ cutout: CGImage) -> CGImage? {
        let margin = max(cutout.width, cutout.height) / 10
        let width = cutout.width + 2 * margin, height = cutout.height + 2 * margin
        guard let context = CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        ) else { return nil }
        context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.draw(cutout, in: CGRect(x: margin, y: margin, width: cutout.width, height: cutout.height))
        return context.makeImage()
    }

    /// The cut-out's opaque pixels on a 24 × 24 grid, top row first.
    private static func outline(of cutout: CGImage) -> GarmentShape? {
        let side = 24
        var pixels = [UInt8](repeating: 0, count: side * side * 4)
        let drawn = pixels.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(
                data: buffer.baseAddress, width: side, height: side, bitsPerComponent: 8, bytesPerRow: side * 4,
                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return false }
            context.draw(cutout, in: CGRect(x: 0, y: 0, width: side, height: side))
            return true
        }
        guard drawn, cutout.width > 0 else { return nil }
        let mask = (0..<side).map { y in (0..<side).map { x in pixels[(y * side + x) * 4 + 3] >= 128 } }
        return GarmentShape(mask: mask, aspect: Double(cutout.height) / Double(cutout.width))
    }

    /// Draws the image upright, at most `maxDimension` points on its longest side.
    private static func redraw(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let scale = min(1, maxDimension / max(image.size.width, image.size.height))
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }
}
