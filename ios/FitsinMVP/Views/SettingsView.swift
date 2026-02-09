import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var session: AppSession

    var body: some View {
        NavigationStack {
            Form {
                Section("Access") {
                    Button("Clear Access Code") {
                        session.signOut()
                    }
                    .foregroundStyle(.red)
                }

                Section("Admin") {
                    NavigationLink("Manual Entries") {
                        ManualEntriesView()
                    }
                }

                Section("Timezone") {
                    Text("Europe/London")
                }
            }
            .navigationTitle("Settings")
        }
    }
}
