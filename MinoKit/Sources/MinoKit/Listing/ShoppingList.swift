import Foundation

/// "Ma liste": what is left to find, in plain text, to share with grandparents or keep for the
/// second-hand shop. No links, no shop.
public enum ShoppingList {
    public static func text(for childName: String, needs: [Need]) -> String {
        let lines = needs.filter { $0.stillMissing > 0 }.map { need in
            "• \(need.group.displayName) : \(need.stillMissing) en \(SizeChart.label(size: need.size, kind: need.group.sizeKind))"
        }
        return (["Pour \(childName) :"] + lines).joined(separator: "\n")
    }
}
