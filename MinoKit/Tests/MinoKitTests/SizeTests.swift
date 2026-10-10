import XCTest
@testable import MinoKit

final class SizeTests: XCTestCase {
    func testLabels() {
        XCTAssertEqual(SizeChart.label(size: 104, kind: .clothing), "4 ans · 104 cm")
        XCTAssertEqual(SizeChart.label(size: 27, kind: .shoes), "Pointure 27")
        XCTAssertEqual(SizeChart.shortLabel(size: 80, kind: .clothing), "18 mois")
    }

    func testSnappingAndWornSize() {
        XCTAssertEqual(SizeChart.snapClothing(100), 98)
        XCTAssertEqual(SizeChart.snapClothing(101), 104)
        XCTAssertEqual(SizeChart.wornClothingSize(forHeight: 104), 104)
        XCTAssertEqual(SizeChart.wornClothingSize(forHeight: 106.5), 110)
        XCTAssertEqual(SizeChart.wornClothingSize(forHeight: SizeChart.typicalHeight(wearing: 116)), 116)
        XCTAssertEqual(SizeChart.nextClothingSize(after: 104), 110)
        XCTAssertNil(SizeChart.nextClothingSize(after: 170))
        XCTAssertEqual(SizeChart.wornShoeSize(forEstimate: 27.2), 28)
    }

    func testParsesCentimetreLabels() {
        XCTAssertEqual(SizeLabelParser.size(in: ["100% coton", "104 cm"], kind: .clothing), 104)
        XCTAssertEqual(SizeLabelParser.size(in: ["110/116 cm"], kind: .clothing), 116)
        XCTAssertEqual(SizeLabelParser.size(in: ["120"], kind: .clothing), 122)
    }

    func testParsesAgeLabels() {
        XCTAssertEqual(SizeLabelParser.size(in: ["4 ans"], kind: .clothing), 104)
        XCTAssertEqual(SizeLabelParser.size(in: ["3-4Y"], kind: .clothing), 104)
        XCTAssertEqual(SizeLabelParser.size(in: ["18 mois"], kind: .clothing), 80)
        XCTAssertEqual(SizeLabelParser.size(in: ["12-18M"], kind: .clothing), 80)
    }

    func testIgnoresWashingInstructions() {
        XCTAssertNil(SizeLabelParser.size(in: ["100%", "30°"], kind: .clothing))
        XCTAssertNil(SizeLabelParser.size(in: ["30°"], kind: .shoes))
    }

    func testParsesShoeSizes() {
        XCTAssertEqual(SizeLabelParser.size(in: ["EU 28"], kind: .shoes), 28)
        XCTAssertEqual(SizeLabelParser.size(in: ["UK 9", "P27"], kind: .shoes), 27)
        XCTAssertEqual(SizeLabelParser.size(in: ["made in 2024", "26"], kind: .shoes), 26)
    }
}
