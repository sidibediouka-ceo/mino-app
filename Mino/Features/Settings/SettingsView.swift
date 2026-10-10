import SwiftData
import SwiftUI

struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Child.createdAt) private var children: [Child]
    @AppStorage("eveningReminderEnabled") private var reminderEnabled = false
    @AppStorage("eveningReminderMinutes") private var reminderMinutes = 19 * 60 + 30
    @State private var editing: Child?
    @State private var addingChild = false
    @State private var confirmingErase = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Enfants") {
                    ForEach(children) { child in
                        Button { editing = child } label: {
                            HStack(spacing: 12) {
                                ChildAvatar(name: child.name, color: children.color(of: child), size: 32)
                                Text(child.name).foregroundStyle(Theme.ink)
                                Spacer()
                                Text(Formatting.age(months: child.ageInMonths)).foregroundStyle(Theme.secondaryText)
                            }
                        }
                    }
                    Button("Ajouter un enfant", systemImage: "plus") { addingChild = true }
                }

                Section {
                    Toggle("Le soir, c'est prêt", isOn: reminderToggle)
                    if reminderEnabled {
                        DatePicker("Heure", selection: reminderTime, displayedComponents: .hourAndMinute)
                    }
                } header: {
                    Text("Notification")
                } footer: {
                    Text("Une seule notification par jour, avec la météo du lendemain. Jamais de publicité.")
                }

                Section {
                    Label("Vos données restent sur cet iPhone", systemImage: "lock")
                    Text("Photos, tailles et analyses sont traitées sur l'appareil. Aucun compte, aucun serveur, aucun suivi. La météo vient d'Apple, à partir d'une position approximative jamais enregistrée.")
                        .font(.footnote)
                        .foregroundStyle(Theme.secondaryText)
                    if let support = URL(string: "mailto:contact.mino.support@gmail.com") {
                        Link("Nous écrire", destination: support)
                    }
                } header: {
                    Text("Confidentialité")
                }

                Section {
                    Button("Effacer toutes les données", role: .destructive) { confirmingErase = true }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background)
            .navigationTitle("Réglages")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("OK") { dismiss() }
                }
            }
            .sheet(item: $editing) { child in
                NavigationStack {
                    ChildFormView(mode: .edit(child)) { _ in editing = nil }
                        .navigationTitle(child.name)
                }
            }
            .sheet(isPresented: $addingChild) {
                NavigationStack {
                    ChildFormView(mode: .create) { _ in addingChild = false }
                        .navigationTitle("Nouvel enfant")
                }
            }
            .confirmationDialog("Effacer toutes les données ?", isPresented: $confirmingErase, titleVisibility: .visible) {
                Button("Tout effacer", role: .destructive, action: eraseAll)
            } message: {
                Text("Enfants, vêtements, photos et mesures seront définitivement supprimés de cet iPhone.")
            }
        }
    }

    private var reminderToggle: Binding<Bool> {
        Binding(get: { reminderEnabled }, set: { enabled in
            if enabled {
                Task { reminderEnabled = await EveningReminder.requestPermission() }
            } else {
                reminderEnabled = false
                EveningReminder.cancel()
            }
        })
    }

    private var reminderTime: Binding<Date> {
        Binding(
            get: { Calendar.current.date(bySettingHour: reminderMinutes / 60, minute: reminderMinutes % 60, second: 0, of: .now) ?? .now },
            set: { date in
                let components = Calendar.current.dateComponents([.hour, .minute], from: date)
                reminderMinutes = (components.hour ?? 19) * 60 + (components.minute ?? 30)
            }
        )
    }

    private func eraseAll() {
        try? context.delete(model: PlannedOutfit.self)
        try? context.delete(model: Garment.self)
        try? context.delete(model: GrowthEntry.self)
        try? context.delete(model: Child.self)
        EveningReminder.cancel()
        dismiss()
    }
}
