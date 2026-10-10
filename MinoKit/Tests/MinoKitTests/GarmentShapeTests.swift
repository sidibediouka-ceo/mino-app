import XCTest
@testable import MinoKit

/// Outlines of 50 real catalogue photos (shoes, tights, trousers, tops, jackets, dresses), cut out
/// and sampled on a 24 × 24 grid, with the category a parent would pick.
final class GarmentShapeTests: XCTestCase {
    private struct Sample {
        let name: String
        let category: GarmentCategory
        let aspect: Double
        let hexMask: String

        var shape: GarmentShape? {
            let bits = hexMask.flatMap { character -> [Bool] in
                let value = Int(String(character), radix: 16) ?? 0
                return (0..<4).map { value & (8 >> $0) != 0 }
            }
            let mask = stride(from: 0, to: 576, by: 24).map { Array(bits[$0..<$0 + 24]) }
            return GarmentShape(mask: mask, aspect: aspect)
        }
    }

    private let samples: [Sample] = [
        Sample(name: "01-baskets_blanches", category: .sneakers, aspect: 0.688, hexMask: "00400000e60000f70038ff8038ff803dffc03fffe07fffe07ffff07ffff87ffffc7ffffe7fffff7fffff7fffff7fffffffffffffffff7fffff1ffffc07fff801fff8007ff80007e0"),
        Sample(name: "02-baskets_beige", category: .sneakers, aspect: 0.685, hexMask: "00800001840001cf003bff803fff803fffc03fffe07fffe07ffff07ffff87ffffc7fffff7fffff7fffff7fffff7fffffffffffffffff7fffff1ffffe07fffc01fffc003ff80001e0"),
        Sample(name: "03-baskets_blanches", category: .sneakers, aspect: 0.697, hexMask: "00800001c00001ee0011ff0039ff803fff803fffc07fffe07ffff07ffff07ffff87ffffe7ffffe7fffff7fffff7fffffffffffffffff7fffff1ffffc07fff001fff8003ff00003c0"),
        Sample(name: "04-baskets_roses", category: .sneakers, aspect: 0.676, hexMask: "030000030800139e003fff003fff003fff807fffc07fffc07fffe07ffff07ffff87ffffc7ffffe7fffff7ffffffffffffffffefffffe7ffffe1ffffc07fff001fff0007ff00007c0"),
        Sample(name: "05-baskets_dorees", category: .sneakers, aspect: 0.715, hexMask: "00c00000c00019ec003dfe003dff003fff003fff803fffc07fffe07ffff07ffff87ffffc7ffffe7ffffe7fffff7ffffffffffffffffe7fffff1ffffe07fff001fff0007ff00007c0"),
        Sample(name: "06-baskets_blanches", category: .sneakers, aspect: 0.667, hexMask: "00400000e00000f70018ff803cff803fffc03fffe03fffe03ffff07ffff87ffffc7ffffe7fffff7fffff7fffff7fffff7fffffffffff7fffff3fffff0ffffc01fffc007ff8000080"),
        Sample(name: "07-baskets_lilas", category: .sneakers, aspect: 0.663, hexMask: "00c00000c80010fe0039ff003dff803fff803fffc07fffe07fffe07ffff07ffff87ffffe7ffffe7fffff7fffff7fffff7ffffefffffe7fffff3ffffe0ffff001fff0007ff0000780"),
        Sample(name: "08-baskets_leopard", category: .sneakers, aspect: 0.642, hexMask: "01800001800033c8003bfc003ffe003ffc007fff007ffe007fff807fff807ffff07ffff87ffffcfffffefffffeffffffffffffffffff7ffffe1ffffe07fffc00fff8003ff80003e0"),
        Sample(name: "09-baskets_blanches", category: .sneakers, aspect: 0.644, hexMask: "00800001800031dc0039fe003fff003fff007fff807fffc07fffe07fffe07ffff07ffff87ffffe7ffffefffffffffffffffffffffffe7ffffe3ffffe07fff801fff8003ff00001c0"),
        Sample(name: "10-baskets_retro", category: .sneakers, aspect: 0.645, hexMask: "0100000390001bdc003bfe003ffe003fff003fff807fffc07fffe07ffff07ffff87ffffc7ffffe7ffffe7ffffffffffffffffefffffe7ffffe1ffffe07fff001fff0003fe0000380"),
        Sample(name: "11-collants_ecru", category: .tights, aspect: 3.497, hexMask: "3ffffe7ffffe7ffffe7ffffe7ffffe7ffffe3ffffe3ffffe1ffffe1ffffc1ffffc1ffffe3ffffe3ffffe3ffffe1ffffc1ffffc0ffff80ffff80ffff80ffff81ffffc7ffffe3ffffc"),
        Sample(name: "12-collants_rose", category: .tights, aspect: 3.349, hexMask: "7ffffe7ffffe7ffffe7ffffe7ffffe7ffffe3ffffe3ffffc1ffffc1ffff81ffffc3ffffc3ffffc3ffffc3ffffc1ffff81ffff80ffff80ffff00ffff00ffff81ffff87ffffc3ffff8"),
        Sample(name: "13-collants_marron", category: .tights, aspect: 3.390, hexMask: "7ffffe7ffffe7fffff7fffff7fffff7ffffe7ffffe3ffffe3ffffc1ffffc1ffffc3ffffc3ffffc3ffffc3ffffc1ffffc1ffff80ffff80ffff00ffff00ffff01ffff87ffffc3feff8"),
        Sample(name: "14-collants_gris", category: .tights, aspect: 3.453, hexMask: "7ffffe7ffffe7ffffefffffe7ffffe7ffffe7ffffe3ffffc3ffffc3ffffc3ffffc3ffffc3ffffc3ffffc3ffffc3ffff81ffff81ffff00ffff00ffff00ffff01ffff87ffffc3fcff8"),
        Sample(name: "15-collants_bleu", category: .tights, aspect: 3.432, hexMask: "7ffffe7ffffe7ffffefffffefffffe7ffffe7ffffe3ffffc3ffffc3ffff83ffff83ffffc3ffffc3ffffc3ffffc1ffff81ffff80ffff00ffff00ffff00ffff01ffff87ffffc1ffff8"),
        Sample(name: "16-collants_ecru", category: .tights, aspect: 3.390, hexMask: "7ffffe7ffffe7ffffe7ffffe7ffffe7ffffe7ffffe3ffffc3ffffc1ffff81ffff83ffffc3ffffc3ffffc3ffffc1ffff81ffff80ffff00ffff00ffff00ffff01ffff87ffffc3ffff8"),
        Sample(name: "17-collants_taupe", category: .tights, aspect: 3.519, hexMask: "7ffffe7ffffeffffffffffffffffff7ffffe7ffffe3ffffc3ffffc3ffffc3ffffc3ffffc3ffffc3ffffe3ffffc3ffffc1ffff81ffff80ffff00ffff00ffff81ffff87ffffc3ffff8"),
        Sample(name: "18-collants_noir", category: .tights, aspect: 3.519, hexMask: "7ffffefffffefffffffffffffffffffffffe7ffffe7ffffc3ffffc3ffff83ffff83ffffc7ffffc7ffffc7ffffc3ffff81ffff81ffff01ffff01ffff01ffff03ffff8fffffc3ffff8"),
        Sample(name: "19-collants_bordeaux", category: .tights, aspect: 3.658, hexMask: "7ffffe7ffffe7ffffe7ffffe7ffffe7ffffe7ffffe7ffffc7ffffc7ffff87ffff87ffffc7ffffc7ffffc7ffffc7ffff87ffff83ffff03ffff03ffff03ffff07ffff07ffffc7ffff8"),
        Sample(name: "20-collants_vert", category: .tights, aspect: 3.757, hexMask: "fffffefffffefffffefffffefffffefffffefffffefffffcfffff8fffff8fffff8fffffcfffffcfffffcfffffcfffff87ffff83ffff03ffff03ffff03ffff07ffff8fffffc7f9ff8"),
        Sample(name: "J-cardigan-cream", category: .cardigan, aspect: 1.101, hexMask: "0040c001fff007fff807fffc0ffffc0ffffc0ffffe1ffffe1ffffe1fffff3fffff3fffff3fffff7fffff7fffff7fffff7ffffffffffffffffffffffffffbff7d000f780003300002"),
        Sample(name: "J-dress-pink", category: .dress, aspect: 1.591, hexMask: "1c00181e00780e007007006007ffe007ffe007ffe007ffe007ffc007ffe007ffe00ffff00ffff01ffff81ffff81ffff83ffffc3ffffc3ffffe7ffffe7ffffe7ffffeffffff01b700"),
        Sample(name: "J-hoodie-lilac", category: .sweater, aspect: 1.084, hexMask: "00ff0001ffc003ffc003ffe007ffe00ffff00ffff81ffff81ffff81ffffc3ffffc3ffffc3ffffe7ffffe7ffffe7fffffffffffffffffffffffffffffffffffefffffe7ffe707e7e0"),
        Sample(name: "J-jacket-denim", category: .lightJacket, aspect: 1.020, hexMask: "007e0000ff0001ff8007ffe00ffff00ffff01ffff81ffff81ffff81ffff83ffffc3ffffc3ffffc3ffffc7ffffe7ffffe7ffffe7ffffe7ffffefffffef8001ff0000ff0000f30000c"),
        Sample(name: "J-jacket-flowers", category: .lightJacket, aspect: 1.149, hexMask: "007e0001ff8003ffc007ffc007ffe00ffff00ffff01ffff01ffff81ffff83ffff83ffffc3ffffc7ffffc7ffffe7ffffe7ffffefffffeffffffffffffffffffffffff2fffec07ffe0"),
        Sample(name: "J-jeans-wide", category: .pants, aspect: 1.764, hexMask: "07ffe007fff007fff00ffff00ffff80ffff80ffff81ffff81ffff81ff7fc1ff7fc1ff7fc3ff7fc3fe7fc3fe7fc3fe7fe3fe7fe7fe7fe7fe7fe7fe7fe7fe7fe7fe7ffffe7ff3fe7fc"),
        Sample(name: "J-leggings-pink", category: .pants, aspect: 2.385, hexMask: "3ffffc3ffffc7ffffe7ffffe7ffffe7ffffe7fffffffffffffffffffffffffe7ffffe7ff7fe7ff7fc3fe7fc3fe7fc3fe7f81fe7f81fe7f81fe7f81fe7f81fe7f00fe7f00fe7f00fe"),
        Sample(name: "J-longsleeve-stripes", category: .longSleeve, aspect: 0.950, hexMask: "01008007ffe01ffff01ffff81ffff83ffff83ffffc3ffffc3ffffc7ffffc7ffffc7ffffc7ffffe7ffffefffffefffffefffffefffffeffffffffffff7ffffe0ffff00ffff00ffff0"),
        Sample(name: "J-skirt-pink", category: .shorts, aspect: 0.923, hexMask: "04006007ffe007ffe007ffe007ffe00ffff00ffff01ffff01ffff81ffff81ffff83ffffc3ffffc3ffffc3ffffc7ffffe7ffffe7ffffe7ffffe7ffffeffffffffffff3ffffc00fe00"),
        Sample(name: "J-tshirt-ruffle", category: .tshirt, aspect: 1.175, hexMask: "01804007fff8ffffff7fffff7fffff7fffff3ffffe3ffffe1ffffe1ffffc0ffff80ffff80ffff80ffff80ffff81ffff81ffff81ffffc1ffffc1ffffc1ffffc1ffffc1ffffc03ffe0"),
        Sample(name: "L-01", category: .sweater, aspect: 0.957, hexMask: "007f0001ff8003ffc003ffc003ffc007ffe00ffff00ffff01ffff81ffff81ffff83ffffc3ffffc3ffffc7ffffe7ffffe7ffffe7ffffefffffffffffff7ffef67ffe607ffe003ffc0"),
        Sample(name: "L-02", category: .sweater, aspect: 0.838, hexMask: "00c30001ff8007ffe00fffe00ffff01ffff01ffff81ffff83ffff83ffffc3ffffc3ffffc7ffffe7ffffe7ffffe7ffffe7ffffefffffffffffffffffffffffff7ffef23ffe603e7c0"),
        Sample(name: "L-03", category: .overalls, aspect: 2.523, hexMask: "0e00e00f81f00fc7e007ffc007ffe00fffe01ffff03ffffc7ffffc7ffffe7ffffe7ffffefffffefffffeffeffeffe7feffe7feffc7feffc3feffc3feff83feff83feff83fe7f81fe"),
        Sample(name: "L-04", category: .pants, aspect: 1.715, hexMask: "3ffff83ffff87ffffc7ffffc7ffffc7ffffc7ffffe7ffffefffffeffeffeffeffeffeffeffe7feffc7feffc7feffc7feffc3feff83feff83feff83feff83feff83feffc3fe7f81fe"),
        Sample(name: "L-05", category: .lightJacket, aspect: 0.877, hexMask: "007e0000ff0001ff8003ffc007ffe00ffff00ffff01ffff01ffff81ffff83ffffc3ffffc3ffffc7ffffe7ffffe7ffffe7ffffe7ffffeffffef77ffef17ffe607ffe003ffe000ff00"),
        Sample(name: "L-06", category: .cardigan, aspect: 1.348, hexMask: "01ff8003ffc007ffc03ffffc3ffffc3ffffc3ffffc3ffff83ffffc3ffffcfffffefffffefffffefffffefffffefffffefffffefffffefffffefffffefffffefffffe7fffff0ffff8"),
        Sample(name: "L-07", category: .raincoat, aspect: 1.049, hexMask: "003e0001ff8001ff8003ffc003ffc003ffc007ffe00ffff00ffff01ffff81ffff83ffffc3ffffc3ffffc7ffffe7ffffefffffff7ffef67ffee07ffe007ffe007ffe007fff001ff80"),
        Sample(name: "L-08", category: .pants, aspect: 1.644, hexMask: "1ffff83ffffc3ffffc7ffffe7ffffe7ffffe7ffffe7ffffe7fffffffffffffffffffe7ffffe7ffffe7ffffe7ffffc7ffffc3ffffc3ffffc3ff7fc3fe7f81fe7f81fe3f00fc3f00fc"),
        Sample(name: "L-09", category: .longSleeve, aspect: 1.047, hexMask: "040c003fff007fffc03fffc03fffe03fffe03ffff03ffff03ffff03ffff83ffff87ffff87ffffc7ffffc7ffffc7ffffc7ffffe7ffffe7fffbeffff9fffff9effffc8ffffc03fff80"),
        Sample(name: "L-10", category: .pajamas, aspect: 1.889, hexMask: "01ff800ffff01ffff81ffff83ffffc3ffffc7ffffe7bffdeffffdff7ffef27ffe407ffe007ffe007ffe007e7e007e7e007e7e007e7e007e7e003c3c003c3c003c3c007c3e007c3e0"),
        Sample(name: "L-11", category: .longSleeve, aspect: 1.011, hexMask: "00804001ffe007fff80ffffc1ffffc1ffffe1ffffe1ffffe3ffffe3fffff3fffff3fffff7fffff7fffff7fffff7fffff7fffff7fffffffffffffffffffffff7fffff0ffff807fff8"),
        Sample(name: "L-12", category: .sweater, aspect: 1.123, hexMask: "007f8001ffe003fff003fff007fff807fff807fff80ffffc0ffffc1ffffe1ffffe1ffffe3fffff3fffff3fffff3fffffffffffffffffffffffffffffffffff77fffb03fff803fff0"),
        Sample(name: "L-13", category: .longSleeve, aspect: 1.030, hexMask: "007e0000ff0003ffc00ffff00ffff81ffff81ffff83ffffc3ffffc3ffffc3ffffe7ffffe7ffffe7ffffe7ffffe7fffffffffffffffffffffffffffff0ffff00ffff007ffe000ff00"),
        Sample(name: "L-14", category: .lightJacket, aspect: 1.069, hexMask: "00fe0001ff0003ff8007ffe00ffff01ffff81ffff83ffffc3ffffc3ffffe7ffffe7ffffe7fffffffffffffffffffffffffffffffffffffffffffffffffffff7ffffe1ffff80ffff0"),
        Sample(name: "L-15", category: .pants, aspect: 1.388, hexMask: "0ffff00ffff00ffff00ffff81ffff81ffff81ffff81ffffc3ffffc3ffffc3ffffc3ff7fc3ff7fc7fe7fe7fe7fe7fe7fe7fe7fe7fc3fe7fc3fe7fc3fe7fc3ffff81ffff81ff0f81f0"),
        Sample(name: "L-16", category: .pants, aspect: 1.411, hexMask: "0ffff00ffff01ffff81ffff83ffffc3ffffc3ffffc3ffffc7ffffe7ffffe7ffffe7ff7fe7ff7feffe7ffffe7ffffe7ffffe7ffffe7ffffc3ffffc3ffffc3ff7f81fe7f81fe0f00f8"),
        Sample(name: "L-17", category: .sweater, aspect: 1.011, hexMask: "00808003ffe007fff80ffffc1ffffc1ffffe3ffffe3ffffe3fffff7fffff7fffff7fffff7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffeffffb070078"),
        Sample(name: "L-18", category: .shorts, aspect: 0.950, hexMask: "0f00f00ffff80ffff81ffff81ffff81ffffc3ffffc3ffffc3ffffc3ffffc3ffffe3ffffe7ffffe7ffffe7ffffe7ffffe7ffffe7ff7ff7ff7ff7ff7ffffe7ffffe7ff1fe7f8006300"),
        Sample(name: "L-19", category: .cardigan, aspect: 1.293, hexMask: "00ff0001ff8003ffc00ffff03ffffc3ffffc3ffffc1ffffc1ffff83ffffc3ffffc3ffffc7ffffefffffffffffffffffffffffffffffffffffffffffffffffffffffe7ffffe7ffffe"),
        Sample(name: "L-20", category: .raincoat, aspect: 1.132, hexMask: "01fe0007ff800fffc00fffc00fffe00fffe01ffff03ffff03ffff87ffff87ffffcfffffcfffffcfffffefffffefffffefffffffffffffffffffffffe1ffff03ffff03ffff01fffe0"),
    ]

    func testTheOutlineAlwaysFindsTheRightFamily() {
        for sample in samples {
            let shape = try? XCTUnwrap(sample.shape)
            XCTAssertTrue(shape?.likelyCategories.contains(sample.category) == true, sample.name)
        }
    }

    /// A skirt has no legs and keeps the shape of a top: only the classifier can tell.
    func testShoesTightsAndTrousersAreRecognisedFromTheirOutlineAlone() {
        for sample in samples where [.sneakers, .tights, .pants].contains(sample.category) || sample.name == "L-18" {
            XCTAssertEqual(CategoryGuess.ranked(fromLabels: [], shape: sample.shape).first, sample.category, sample.name)
        }
    }

    func testTheOutlineAloneGetsMostGarmentsRightFirstTime() {
        let right = samples.filter { CategoryGuess.ranked(fromLabels: [], shape: $0.shape).first == $0.category }
        XCTAssertGreaterThanOrEqual(Double(right.count) / Double(samples.count), 0.7)
    }

    func testTheOutlineOverrulesALabelThatCannotHaveThatShape() {
        let jacket = samples.first { $0.name == "J-jacket-denim" }?.shape
        XCTAssertEqual(CategoryGuess.ranked(fromLabels: [("jeans", 0.5), ("jacket", 0.3)], shape: jacket).first, .lightJacket)
        XCTAssertFalse(CategoryGuess.ranked(fromLabels: [("jeans", 0.5), ("jacket", 0.3)], shape: jacket).contains(.pants))
        let skirt = samples.first { $0.name == "J-skirt-pink" }?.shape
        XCTAssertEqual(CategoryGuess.ranked(fromLabels: [("skirt", 0.4)], shape: skirt).first, .shorts)
        let sneakers = samples.first { $0.category == .sneakers }?.shape
        XCTAssertEqual(CategoryGuess.ranked(fromLabels: [("sandal", 0.3)], shape: sneakers).first, .sandals)
    }

    func testMinosClassifierLeadsAndAppleRefinesWithinTheFamily() {
        let jacket = samples.first { $0.name == "L-20" }?.shape
        XCTAssertEqual(CategoryGuess.ranked(fromLabels: [], shape: jacket, families: [("outerwear", 0.9)]).first, .lightJacket)
        XCTAssertEqual(CategoryGuess.ranked(fromLabels: [("raincoat", 0.6)], shape: jacket, families: [("outerwear", 0.9)]).first, .raincoat)
        // A wrong family is still overruled by an outline that cannot have it.
        let tights = samples.first { $0.category == .tights }?.shape
        XCTAssertEqual(CategoryGuess.ranked(fromLabels: [], shape: tights, families: [("longsleeve", 0.5), ("tights", 0.4)]).first, .tights)
        XCTAssertEqual(Set(CategoryGuess.classifierFamilies.values.flatMap { $0 }), Set(GarmentCategory.allCases))
    }

    func testATinyMaskIsIgnored() {
        XCTAssertNil(GarmentShape(mask: [[true]], aspect: 1))
    }
}
