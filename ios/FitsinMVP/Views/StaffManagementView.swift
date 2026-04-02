import SwiftUI

struct StaffManagementView: View {
    @State private var staffNames: [String] = []
    @State private var newName = ""
    @State private var showAddSheet = false
    @State private var resetTarget: String?
    @State private var showResetConfirm = false
    @State private var showResetInput = false
    @State private var newPinInput = ""
    @State private var resetSuccess: String?
    @State private var animateIn = false

    var body: some View {
        ZStack {
            DashboardBackground()

            ScrollView {
                VStack(spacing: 0) {
                    headerSection
                    staffList

                    if let name = resetSuccess {
                        pinSuccessBanner(name: name)
                    }
                }
                .opacity(animateIn ? 1 : 0)
                .offset(y: animateIn ? 0 : 12)
            }
        }
        .navigationTitle("Staff & PINs")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showAddSheet = true
                } label: {
                    Image(systemName: "plus")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(BrandTheme.ink)
                }
            }
        }
        .task {
            staffNames = StaffDirectory.allNames
            animateIn = false
            withAnimation(.easeOut(duration: 0.4)) {
                animateIn = true
            }
        }
        .alert("Add Staff Member", isPresented: $showAddSheet) {
            TextField("Name", text: $newName)
            Button("Add") {
                let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    StaffDirectory.addName(trimmed)
                    staffNames = StaffDirectory.allNames
                    newName = ""
                }
            }
            Button("Cancel", role: .cancel) { newName = "" }
        }
        .alert("Reset PIN for \(resetTarget ?? "")?", isPresented: $showResetConfirm) {
            Button("Reset", role: .destructive) {
                showResetInput = true
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will replace their current PIN. They'll need the new one to sign in.")
        }
        .alert("New PIN for \(resetTarget ?? "")", isPresented: $showResetInput) {
            TextField("6-digit PIN", text: $newPinInput)
                .keyboardType(.numberPad)
            Button("Set PIN") {
                if newPinInput.count == 6, let name = resetTarget {
                    StaffDirectory.setPin(newPinInput, for: name)
                    resetSuccess = name
                    newPinInput = ""
                }
            }
            Button("Cancel", role: .cancel) { newPinInput = "" }
        } message: {
            Text("Choose a 6-digit PIN for them.")
        }
    }

    private var headerSection: some View {
        VStack(spacing: 4) {
            Text("STAFF DIRECTORY")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .tracking(1.5)
                .foregroundStyle(BrandTheme.inkSoft)
            Text("\(staffNames.count) members")
                .font(.caption)
                .foregroundStyle(BrandTheme.inkSoft)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }

    private var staffList: some View {
        VStack(spacing: 0) {
            ForEach(Array(staffNames.enumerated()), id: \.element) { index, name in
                if index > 0 {
                    Divider().overlay(BrandTheme.divider).padding(.horizontal, 20)
                }

                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(name)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(BrandTheme.ink)

                            if StaffDirectory.isAdmin(name) {
                                Text("ADMIN")
                                    .font(.system(size: 9, weight: .bold, design: .rounded))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Capsule().fill(BrandTheme.accent.opacity(0.15)))
                                    .foregroundStyle(BrandTheme.accent)
                            }
                        }

                        Text(StaffDirectory.hasPin(name) ? "PIN set" : "No PIN yet")
                            .font(.system(size: 11))
                            .foregroundStyle(BrandTheme.inkSoft)
                    }

                    Spacer()

                    Button {
                        resetTarget = name
                        showResetConfirm = true
                    } label: {
                        Text("Reset PIN")
                            .font(.system(size: 12, weight: .semibold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                Capsule().fill(BrandTheme.ink.opacity(0.06))
                            )
                            .foregroundStyle(BrandTheme.ink)
                    }
                    .buttonStyle(.plain)

                    if !StaffDirectory.isAdmin(name) {
                        Button {
                            StaffDirectory.removeName(name)
                            StaffDirectory.clearPin(for: name)
                            staffNames = StaffDirectory.allNames
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.body)
                                .foregroundStyle(BrandTheme.danger.opacity(0.6))
                        }
                        .buttonStyle(.plain)
                    }
                }
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
    }

    private func pinSuccessBanner(name: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.title)
                .foregroundStyle(BrandTheme.success)
            Text("PIN updated for \(name)")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(BrandTheme.ink)
            Text("Let them know their new code.")
                .font(.caption)
                .foregroundStyle(BrandTheme.inkSoft)

            Button {
                resetSuccess = nil
            } label: {
                Text("Done")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(BrandTheme.ink))
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(BrandTheme.success.opacity(0.08))
        )
        .padding(20)
    }
}
