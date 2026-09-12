import SwiftUI

/// Dua tanggal yang menjadi titik nol seluruh jadwal, plus tanggal bunga
/// pertama kalau sudah terlihat.
struct ScheduleDatesEditorView: View {
    let fieldID: UUID

    @EnvironmentObject private var settingsStore: ScheduleSettingsStore
    @Environment(\.dismiss) private var dismiss

    @State private var hasSowing = false
    @State private var sowingDate = Date()
    @State private var hasTransplant = false
    @State private var transplantDate = Date()
    @State private var hasFlower = false
    @State private var flowerDate = Date()
    @State private var notice: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Sudah disemai", isOn: $hasSowing)
                    if hasSowing {
                        DatePicker("Tanggal semai", selection: $sowingDate, displayedComponents: .date)
                    }
                } footer: {
                    Text("Umur tanaman dihitung dari tanggal ini (HSS).")
                }

                Section {
                    Toggle("Sudah dipindah tanam", isOn: $hasTransplant)
                    if hasTransplant {
                        DatePicker("Tanggal pindah tanam", selection: $transplantDate, displayedComponents: .date)
                    }
                } footer: {
                    Text("Seluruh rekomendasi pupuk memakai HST — hari setelah pindah tanam. Selama tanggal ini kosong, tanaman dianggap masih di persemaian dan belum ada pemupukan susulan.")
                }

                Section {
                    Toggle("Bunga pertama sudah terlihat", isOn: $hasFlower)
                    if hasFlower {
                        DatePicker("Tanggal bunga pertama", selection: $flowerDate, displayedComponents: .date)
                    }
                } footer: {
                    Text("Pengamatan mengalahkan kalender. Kalau tanggal ini diisi, batas fase digeser mengikutinya — lebar tiap fase tetap, hanya posisinya yang bergerak.")
                }
            }
            .navigationTitle("Tanggal tanam")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Batal") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Simpan") { save() }
                }
            }
            .onAppear(perform: loadExisting)
            .alert("Perhatian", isPresented: Binding(
                get: { notice != nil },
                set: { if !$0 { notice = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(notice ?? "")
            }
        }
    }

    private func loadExisting() {
        let existing = settingsStore.settings(for: fieldID)
        if let date = existing.sowingDate { hasSowing = true; sowingDate = date }
        if let date = existing.transplantDate { hasTransplant = true; transplantDate = date }
        if let date = existing.firstFlowerDate { hasFlower = true; flowerDate = date }
    }

    private func save() {
        var updated = settingsStore.settings(for: fieldID)
        updated.sowingDate = hasSowing ? sowingDate : nil
        updated.transplantDate = hasTransplant ? transplantDate : nil
        updated.firstFlowerDate = hasFlower ? flowerDate : nil
        switch settingsStore.update(updated) {
        case .success:
            dismiss()
        case let .failure(error):
            notice = error.message
        }
    }
}
