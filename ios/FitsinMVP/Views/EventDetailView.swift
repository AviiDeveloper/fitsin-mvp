import SwiftUI

struct EventDetailView: View {
    let eventId: String
    let fallbackEvent: CalendarEvent

    @StateObject private var vm = EventDetailViewModel()
    @State private var isEditing = false
    @State private var showDeleteAlert = false
    @Environment(\.dismiss) private var dismiss

    private static let timeFmt: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEE d MMM, HH:mm"
        f.timeZone = TimeZone(identifier: "Europe/London")
        f.locale = Locale(identifier: "en_GB")
        return f
    }()

    private static let dateFmt: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEE d MMM yyyy"
        f.timeZone = TimeZone(identifier: "Europe/London")
        f.locale = Locale(identifier: "en_GB")
        return f
    }()

    var body: some View {
        ZStack {
            DashboardBackground()

            ScrollView {
                VStack(spacing: 0) {
                    let event = vm.event ?? fallbackEvent

                    if isEditing {
                        editContent
                    } else {
                        readContent(event: event)
                    }
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(isEditing ? "Edit Event" : "Event")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(BrandTheme.ink)
            }
            ToolbarItem(placement: .topBarTrailing) {
                if isEditing {
                    Button {
                        Task {
                            await vm.save(eventId: eventId)
                            if vm.errorText == nil { isEditing = false }
                        }
                    } label: {
                        if vm.isSaving {
                            ProgressView()
                        } else {
                            Text("Save")
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(BrandTheme.ink)
                        }
                    }
                    .disabled(vm.isSaving)
                } else {
                    Button {
                        isEditing = true
                    } label: {
                        Text("Edit")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(BrandTheme.ink)
                    }
                }
            }
            if isEditing {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        vm.resetDraft()
                        isEditing = false
                    }
                    .foregroundStyle(BrandTheme.ink)
                }
            }
        }
        .task {
            await vm.load(eventId: eventId)
        }
        .onChange(of: vm.didDelete) { _, deleted in
            if deleted { dismiss() }
        }
        .alert("Delete Event", isPresented: $showDeleteAlert) {
            Button("Delete", role: .destructive) {
                Task { await vm.delete(eventId: eventId) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently remove this event from the calendar.")
        }
    }

    // MARK: - Read Mode

    private func readContent(event: CalendarEvent) -> some View {
        VStack(spacing: 0) {
            VStack(spacing: 8) {
                Text("EVENT")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .tracking(1.5)
                    .foregroundStyle(BrandTheme.inkSoft)

                Text(event.title)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(BrandTheme.ink)
                    .multilineTextAlignment(.center)

                if event.isAllDay {
                    if let start = event.startDate {
                        Text(Self.dateFmt.string(from: start))
                            .font(.subheadline)
                            .foregroundStyle(BrandTheme.inkSoft)
                    }
                    StatusPill(text: "All Day", tone: BrandTheme.accent)
                } else {
                    if let start = event.startDate {
                        Text(Self.timeFmt.string(from: start))
                            .font(.subheadline)
                            .foregroundStyle(BrandTheme.inkSoft)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)

            VStack(spacing: 0) {
                if let loc = event.location, !loc.isEmpty {
                    detailRow(icon: "mappin.and.ellipse", label: "Location", value: loc)
                    Divider().overlay(BrandTheme.divider).padding(.horizontal, 20)
                }

                if !event.isAllDay, let start = event.startDate, let end = event.endDate {
                    detailRow(icon: "clock", label: "Time", value: "\(Self.timeFmt.string(from: start)) – \(Self.timeFmt.string(from: end))")
                    Divider().overlay(BrandTheme.divider).padding(.horizontal, 20)
                }

                if let desc = event.description, !desc.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            Image(systemName: "text.alignleft")
                                .font(.caption)
                                .foregroundStyle(BrandTheme.inkSoft)
                            Text("Notes")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(BrandTheme.inkSoft)
                        }
                        Text(desc)
                            .font(.system(size: 14))
                            .foregroundStyle(BrandTheme.ink)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 14)
                }
            }
            .background(BrandTheme.surfaceStrong)
            .overlay(
                VStack {
                    Divider().overlay(BrandTheme.outline)
                    Spacer()
                    Divider().overlay(BrandTheme.outline)
                }
            )

            VStack(spacing: 10) {
                if let link = event.htmlLink, let url = URL(string: link) {
                    Link(destination: url) {
                        HStack {
                            Image(systemName: "arrow.up.right.square")
                            Text("Open in Google Calendar")
                                .font(.subheadline.weight(.semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(BrandTheme.ink.opacity(0.06))
                        )
                        .foregroundStyle(BrandTheme.ink)
                    }
                }

                Button {
                    showDeleteAlert = true
                } label: {
                    HStack {
                        Image(systemName: "trash")
                        Text("Delete Event")
                            .font(.subheadline.weight(.semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(BrandTheme.danger.opacity(0.08))
                    )
                    .foregroundStyle(BrandTheme.danger)
                }
            }
            .padding(20)

            if let error = vm.errorText {
                InlineNotice(text: error, tone: BrandTheme.danger, systemImage: "exclamationmark.triangle.fill")
                    .padding(.horizontal, 20)
            }
        }
    }

    private func detailRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(BrandTheme.inkSoft)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(BrandTheme.inkSoft)
                Text(value)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(BrandTheme.ink)
            }
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    // MARK: - Edit Mode

    private var editContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            TextField("Event title", text: $vm.draft.title)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(BrandTheme.ink)
                .textFieldStyle(FitsinInputStyle())

            Toggle("All Day", isOn: $vm.draft.isAllDay)
                .tint(BrandTheme.ink)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(BrandTheme.ink)

            if vm.draft.isAllDay {
                DatePicker("Date", selection: $vm.draft.startDate, displayedComponents: .date)
                    .datePickerStyle(.compact)
                    .tint(BrandTheme.ink)
                    .foregroundStyle(BrandTheme.ink)
            } else {
                DatePicker("Start", selection: $vm.draft.startDate)
                    .datePickerStyle(.compact)
                    .tint(BrandTheme.ink)
                    .foregroundStyle(BrandTheme.ink)

                DatePicker("End", selection: $vm.draft.endDate)
                    .datePickerStyle(.compact)
                    .tint(BrandTheme.ink)
                    .foregroundStyle(BrandTheme.ink)
            }

            TextField("Location", text: $vm.draft.location)
                .foregroundStyle(BrandTheme.ink)
                .textFieldStyle(FitsinInputStyle())

            VStack(alignment: .leading, spacing: 6) {
                Text("Notes")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(BrandTheme.inkSoft)
                TextEditor(text: $vm.draft.description)
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

            if let error = vm.errorText {
                InlineNotice(text: error, tone: BrandTheme.danger, systemImage: "exclamationmark.triangle.fill")
            }
        }
        .padding(20)
    }
}
