import SwiftUI

struct ManualEntriesView: View {
    @StateObject private var vm = ManualEntriesViewModel()

    private var gbp: NumberFormatter {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = "GBP"
        f.locale = Locale(identifier: "en_GB")
        return f
    }

    var body: some View {
        List {
            if vm.entries.isEmpty {
                Text("No manual entries for this month yet.")
                    .foregroundStyle(BrandTheme.inkSoft)
            } else {
                ForEach(vm.entries) { entry in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(gbp.string(from: NSNumber(value: entry.amount)) ?? "£0")
                                .font(.headline)
                                .foregroundStyle(BrandTheme.ink)
                            Spacer()
                            Text(entry.source.label)
                                .font(.caption.weight(.bold))
                                .foregroundStyle(BrandTheme.accent)
                        }
                        Text(entry.date)
                            .font(.caption)
                            .foregroundStyle(BrandTheme.inkSoft)
                        if let description = entry.description, !description.isEmpty {
                            Text("Description: \(description)")
                                .font(.subheadline)
                                .foregroundStyle(BrandTheme.inkSoft)
                        }
                        if let note = entry.note, !note.isEmpty {
                            Text("Note: \(note)")
                                .font(.subheadline)
                                .foregroundStyle(BrandTheme.inkSoft)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }

            if let errorText = vm.errorText {
                Text(errorText)
                    .foregroundStyle(BrandTheme.danger)
            }
        }
        .navigationTitle("Manual Entries")
        .refreshable { await vm.load() }
        .task {
            await vm.load()
            vm.startAutoRefresh(intervalSeconds: 15)
        }
        .onDisappear { vm.stopAutoRefresh() }
    }
}
