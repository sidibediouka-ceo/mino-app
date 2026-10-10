import MinoKit
import SwiftData
import SwiftUI

/// Creates or edits a child. On creation we ask for the size on the label of the clothes the
/// child wears now, which parents know, rather than a stature in centimetres, which they rarely do.
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
    @State private var birthDate = Calendar.current.date(byAdding: .year, value: -3, to: .now) ?? .now
    @State private var sex: Sex = .unspecified
    @State private var clothingSize = 98
    @State private var shoeSize = 25
    @State private var sizesTouched = false
    @State private var confirmingDeletion = false

    private var isCreating: Bool {
        if case .create = mode { return true }
        return false
    }

    var body: some View {
        Form {
            Section("Prénom") {
                TextField("Prénom", text: $name)
                    .textContentType(.givenName)
            }
            Section {
                DatePicker("Date de naissance", selection: $birthDate, in: ...Date.now, displayedComponents: .date)
                    .environment(\.locale, Locale(identifier: "fr_FR"))
                ChipPicker(options: Sex.allCases, selection: $sex) { option in
                    switch option {
                    case .girl: return "Fille"
                    case .boy: return "Garçon"
                    case .unspecified: return "Non précisé"
                    }
                }
            } footer: {
                Text("Utilisé uniquement pour les courbes de croissance.")
            }
            if isCreating {
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
        .onChange(of: birthDate) { suggestSizes() }
        .onChange(of: sex) { suggestSizes() }
        .confirmationDialog("Supprimer ce profil ?", isPresented: $confirmingDeletion, titleVisibility: .visible) {
            Button("Supprimer", role: .destructive, action: delete)
        } message: {
            Text("Ses vêtements seront rangés dans les cartons de la famille.")
        }
    }

    /// Marks sizes as chosen by the parent so a later birth date change does not override them.
    private func touched(_ binding: Binding<Int>) -> Binding<Int> {
        Binding(get: { binding.wrappedValue }, set: { binding.wrappedValue = $0; sizesTouched = true })
    }

    private func load() {
        if case .edit(let child) = mode {
            name = child.name
            birthDate = child.birthDate
            sex = child.sex
        } else {
            suggestSizes()
        }
    }

    private func suggestSizes() {
        guard isCreating, !sizesTouched else { return }
        let typical = ChildProfile(id: UUID(), name: name, birthDate: birthDate, sex: sex, records: [])
        clothingSize = typical.currentSize(.clothing, on: .now)
        shoeSize = typical.currentSize(.shoes, on: .now)
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        switch mode {
        case .create:
            let child = Child(name: trimmed, birthDate: birthDate, sex: sex)
            context.insert(child)
            let entry = GrowthEntry(
                date: .now, heightCM: SizeChart.typicalHeight(wearing: clothingSize),
                shoeSize: Double(shoeSize), isApproximate: true
            )
            context.insert(entry)
            entry.child = child
            onDone(child)
        case .edit(let child):
            child.name = trimmed
            child.birthDate = birthDate
            child.sex = sex
            onDone(child)
        }
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
