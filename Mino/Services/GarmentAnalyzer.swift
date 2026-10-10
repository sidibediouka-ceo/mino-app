import CoreImage
import MinoKit
import UIKit
import Vision

/// What Mino understood from a photo. Everything runs on device with Apple Vision.
struct GarmentAnalysis: Sendable {
    /// Background-free PNG when the subject could be lifted, the plain photo otherwise.
    let photo: Data
    /// Most likely categories first; empty when Vision has no idea.
    let categories: [GarmentCategory]
    let color: GarmentColor?
    /// Text read on the photo (a visible label often carries the size).
    let texts: [String]
}

enum GarmentAnalyzer {
    static func analyze(_ image: UIImage) async -> GarmentAnalysis {
        await Task.detached(priority: .userInitiated) {
            let upright = redraw(image, maxDimension: 1024)
            guard let cgImage = upright.cgImage else {
                return GarmentAnalysis(photo: upright.pngData() ?? Data(), categories: [], color: nil, texts: [])
            }
            let cutout = liftSubject(from: cgImage)
            let stored = redraw(UIImage(cgImage: cutout ?? cgImage), maxDimension: 600)
            return GarmentAnalysis(
                photo: stored.pngData() ?? Data(),
                categories: classify(cgImage),
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

    private static func classify(_ image: CGImage) -> [GarmentCategory] {
        let request = VNClassifyImageRequest()
        guard (try? VNImageRequestHandler(cgImage: image).perform([request])) != nil else { return [] }
        let labels = (request.results ?? []).prefix(20).map { (identifier: $0.identifier, confidence: $0.confidence) }
        return CategoryGuess.ranked(fromLabels: Array(labels))
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
