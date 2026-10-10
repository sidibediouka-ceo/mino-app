import MinoKit
import SwiftData
import SwiftUI

/// Creates or edits a child with the minimum Mino needs: a first name or nickname, an age and
/// the sizes on the labels of the clothes the child wears now. No date of birth, no sex.
struct ChildFormView: View {
    enum Mode {
        case create
        case edit(Child)
    }

    let mode: Mode
    let onDone: (Child) -> Void

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var ageInMonths = 36
    @State private var clothingSize = 98
    @State private var shoeSize = 25
    @State private var sizesTouched = false
    @State private var confirmingDeletion = false

    /// Month by month until 2, then year by year until 16.
    private static let ageOptions = Array(0..<24) + stride(from: 24, through: 192, by: 12)

    private static func nearestOption(to months: Int) -> Int {
        ageOptions.min { abs($0 - months) < abs($1 - months) } ?? months
    }

    private var isCreating: Bool {
        if case .create = mode { return true }
        return false
    }

    var body: some View {
        Form {
            Section {
                TextField("Prénom ou surnom", text: $name)
                    .textContentType(.nickname)
            } footer: {
                Text("Un surnom suffit : il sert seulement à reconnaître ses tenues.")
            }
            Section {
                Picker("Âge", selection: $ageInMonths) {
                    ForEach(Self.ageOptions, id: \.self) { months in
                        Text(Formatting.age(months: months)).tag(months)
                    }
                }
            } footer: {
                Text("Mino n'a besoin ni de sa date de naissance ni de son sexe.")
            }
            Section {
                ChipPicker(options: SizeChart.clothingSizes, selection: touched($clothingSize)) {
                    SizeChart.shortLabel(size: $0, kind: .clothing)
                }
                Stepper("Pointure \(shoeSize)", value: touched($shoeSize), in: SizeChart.shoeSizes[0]...SizeChart.shoeSizes[SizeChart.shoeSizes.count - 1])
            } header: {
                Text("Sa taille en ce moment")
            } footer: {
                Text("La taille indiquée sur l'étiquette de ses vêtements actuels. Mino affinera avec le temps.")
            }
            Section {
                Button(isCreating ? "Continuer" : "Enregistrer", action: save)
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
            }
            if case .edit = mode {
                Section {
                    Button("Supprimer ce profil", role: .destructive) { confirmingDeletion = true }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.background)
        .onAppear(perform: load)
        .onChange(of: ageInMonths) { suggestSizes() }
        .confirmationDialog("Supprimer ce profil ?", isPresented: $confirmingDeletion, titleVisibility: .visible) {
            Button("Supprimer", role: .destructive, action: delete)
        } message: {
            Text("Ses vêtements seront rangés dans les cartons de la famille.")
        }
    }

    /// Marks sizes as chosen by the parent so a later age change does not override them.
    private func touched(_ binding: Binding<Int>) -> Binding<Int> {
        Binding(get: { binding.wrappedValue }, set: { binding.wrappedValue = $0; sizesTouched = true })
    }

    private func load() {
        guard case .edit(let child) = mode else {
            suggestSizes()
            return
        }
        let profile = child.profile
        name = child.name
        ageInMonths = Self.nearestOption(to: child.ageInMonths)
        clothingSize = profile.currentSize(.clothing, on: .now)
        shoeSize = profile.currentSize(.shoes, on: .now)
        sizesTouched = true
    }

    private func suggestSizes() {
        guard !sizesTouched else { return }
        let typical = ChildProfile(
            id: UUID(), name: name,
            estimatedBirth: ChildProfile.estimatedBirth(ageInMonths: ageInMonths, on: .now), records: []
        )
        clothingSize = typical.currentSize(.clothing, on: .now)
        shoeSize = typical.currentSize(.shoes, on: .now)
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        let child: Child
        switch mode {
        case .create:
            child = Child(name: trimmed, ageInMonths: ageInMonths)
            context.insert(child)
            recordSizes(for: child)
        case .edit(let existing):
            child = existing
            child.name = trimmed
            // Only an age the parent actually changed replaces the one that keeps counting since entry.
            if ageInMonths != Self.nearestOption(to: child.ageInMonths) {
                child.ageInMonths = ageInMonths
            }
            let profile = child.profile
            if clothingSize != profile.currentSize(.clothing, on: .now) || shoeSize != profile.currentSize(.shoes, on: .now) {
                recordSizes(for: child)
            }
        }
        onDone(child)
    }

    /// The sizes the parent gave become an approximate growth record.
    private func recordSizes(for child: Child) {
        let entry = GrowthEntry(
            date: .now, heightCM: SizeChart.typicalHeight(wearing: clothingSize),
            shoeSize: Double(shoeSize), isApproximate: true
        )
        context.insert(entry)
        entry.child = child
    }

    private func delete() {
        guard case .edit(let child) = mode else { return }
        for garment in child.garments ?? [] where garment.state == .active {
            garment.move(to: .stored, owner: nil)
        }
        context.delete(child)
        dismiss()
    }
}
