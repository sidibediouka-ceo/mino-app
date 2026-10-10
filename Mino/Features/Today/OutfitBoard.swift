import MinoKit
import SwiftUI

/// An outfit laid out like a flat-lay: the main pieces large on the left (top, dress or set,
/// bottom), the rest smaller on the right, from head to feet (hat, coat, layers, tights, shoes).
struct OutfitBoard: View {
    let pieces: [OutfitPiece]
    let family: FamilySnapshot

    private static let mainSlots: [OutfitSlot] = [.top, .onePiece, .bottom]
    private static let sideSlots: [OutfitSlot] = [.accessory, .outerwear, .layer, .legwear, .shoes]

    var body: some View {
        let main = Self.mainSlots.flatMap { slot in pieces.filter { $0.slot == slot } }
        let side = Self.sideSlots.flatMap { slot in pieces.filter { $0.slot == slot } }
        HStack(alignment: .top, spacing: 10) {
            if !main.isEmpty {
                VStack(spacing: 10) {
                    ForEach(main, id: \.itemID) { tile($0) }
                }
                .frame(maxWidth: .infinity)
            }
            if !side.isEmpty {
                VStack(spacing: 10) {
                    ForEach(side, id: \.itemID) { tile($0) }
                }
                .frame(maxWidth: main.isEmpty ? .infinity : 104)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(pieces.compactMap { family.garment($0.itemID)?.summary }.joined(separator: ", "))
    }

    private func tile(_ piece: OutfitPiece) -> some View {
        GarmentImage(photo: family.garment(piece.itemID)?.photo)
            .aspectRatio(1, contentMode: .fit)
    }
}
