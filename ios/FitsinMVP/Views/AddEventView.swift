import SwiftUI

struct AddEventView: View {
    let selectedDate: Date
    let onCreated: (CalendarEvent) -> Void

    @State private var draft = CalendarEventDraft()
    @State private var isSaving = false
    @State private var errorText: String?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                DashboardBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        TextField("Event title", text: $draft.title)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(BrandTheme.ink)
                            .textFieldStyle(FitsinInputStyle())

                        Toggle("All Day", isOn: $draft.isAllDay)
                            .tint(BrandTheme.ink)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(BrandTheme.ink)

                        if draft.isAllDay {
                            DatePicker("Date", selection: $draft.startDate, displayedComponents: .date)
                                .datePickerStyle(.compact)
                                .tint(BrandTheme.ink)
                                .foregroundStyle(BrandTheme.ink)
                        } else {
                            DatePicker("Start", selection: $draft.startDate)
                                .datePickerStyle(.compact)
                                .tint(BrandTheme.ink)
                                .foregroundStyle(BrandTheme.ink)

                            DatePicker("End", selection: $draft.endDate)
                                .datePickerStyle(.compact)
                                .tint(BrandTheme.ink)
                                .foregroundStyle(BrandTheme.ink)
                        }

                        TextField("Location (optional)", text: $draft.location)
                            .foregroundStyle(BrandTheme.ink)
                            .textFieldStyle(FitsinInputStyle())

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Notes")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(BrandTheme.inkSoft)
                            TextEditor(text: $draft.description)
                                .foregroundStyle(BrandTheme.ink)
                                .scrollContentBackground(.hidden)
                                .frame(minHeight: 100)
                                .padding(10)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.white)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(BrandTheme.outline, lineWidth: 1)
                                )
                        }

                        if let error = errorText {
                            InlineNotice(text: error, tone: BrandTheme.danger, systemImage: "exclamationmark.triangle.fill")
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("New Event")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(BrandTheme.ink)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await save() }
                    } label: {
                        if isSaving {
                            ProgressView()
                        } else {
                            Text("Add")
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(canSave ? BrandTheme.ink : BrandTheme.inkSoft)
                        }
                    }
                    .disabled(!canSave || isSaving)
                }
            }
        }
        .onAppear {
            var cal = Calendar(identifier: .gregorian)
            cal.timeZone = TimeZone(identifier: "Europe/London") ?? .current
            let noon = cal.date(bySettingHour: 12, minute: 0, second: 0, of: selectedDate) ?? selectedDate
            draft.startDate = noon
            draft.endDate = noon.addingTimeInterval(3600)
        }
    }

    private var canSave: Bool {
        !draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func save() async {
        isSaving = true
        defer { isSaving = false }

        if draft.isAllDay {
            draft.endDate = draft.startDate.addingTimeInterval(86400)
        }

        do {
            let event = try await CalendarService.shared.createEvent(draft)
            onCreated(event)
            dismiss()
        } catch {
            errorText = "Could not create event."
        }
    }
}
