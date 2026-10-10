import MinoKit
import SwiftData
import SwiftUI

/// Thirty seconds, every three or four months, to sharpen every projection.
struct MeasureView: View {
    let child: Child

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var height: Double = 100
    @State private var shoeSize = 25

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("\(height, specifier: "%.1f") cm")
                            .font(.system(.largeTitle, design: .rounded).weight(.bold))
                            .foregroundStyle(Theme.forest)
                        Slider(value: $height, in: 45...190, step: 0.5)
                        Stepper("Ajuster", value: $height, in: 45...190, step: 0.5)
                    }
                } header: {
                    Text("Taille")
                } footer: {
                    Text("Debout, pieds nus, dos contre un mur. Une mesure tous les 3 ou 4 mois suffit.")
                }
                Section("Pointure") {
                    Stepper("Pointure \(shoeSize)", value: $shoeSize, in: SizeChart.shoeSizes[0]...SizeChart.shoeSizes[SizeChart.shoeSizes.count - 1])
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background)
            .navigationTitle("Mesurer \(child.name)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Enregistrer", action: save)
                }
            }
            .onAppear {
                let profile = child.profile
                height = (profile.height(at: .now).expected * 2).rounded() / 2
                shoeSize = profile.currentSize(.shoes, on: .now)
            }
        }
    }

    private func save() {
        let entry = GrowthEntry(date: .now, heightCM: height, shoeSize: Double(shoeSize), isApproximate: false)
        context.insert(entry)
        entry.child = child
        dismiss()
    }
}
