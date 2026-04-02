import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var session: AppSession
    @EnvironmentObject private var calendarAuth: CalendarAuthManager
    @State private var animateIn = false

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                DashboardBackground()

                ScrollView {
                    VStack(spacing: 18) {
                        headerCard

                        DashboardSection(title: "Preferences") {
                            NavigationLink {
                                NotificationSettingsView()
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: "bell.fill")
                                        .font(.title3.weight(.semibold))
                                        .foregroundStyle(BrandTheme.ink)
                                        .frame(width: 36, height: 36)
                                        .background(
                                            RoundedRectangle(cornerRadius: 10)
                                                .fill(BrandTheme.ink.opacity(0.06))
                                        )
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Notifications")
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(BrandTheme.ink)
                                        Text("Sale alerts, daily summary, rota reminders")
                                            .font(.caption)
                                            .foregroundStyle(BrandTheme.inkSoft)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(BrandTheme.inkSoft)
                                }
                                .padding(14)
                                .background(
                                    RoundedRectangle(cornerRadius: 14)
                                        .fill(BrandTheme.surfaceStrong)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(BrandTheme.outline, lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                            .vintageCard()
                        }

                        DashboardSection(title: "Admin", subtitle: "Data and internal controls") {
                            NavigationLink {
                                SellerSalesView()
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: "person.2.fill")
                                        .font(.title3.weight(.semibold))
                                        .foregroundStyle(BrandTheme.ink)
                                        .frame(width: 36, height: 36)
                                        .background(
                                            RoundedRectangle(cornerRadius: 10)
                                                .fill(BrandTheme.ink.opacity(0.06))
                                        )
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Seller Commission")
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(BrandTheme.ink)
                                        Text("Track TA, AA, HW sales and commission")
                                            .font(.caption)
                                            .foregroundStyle(BrandTheme.inkSoft)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(BrandTheme.inkSoft)
                                }
                                .padding(14)
                                .background(
                                    RoundedRectangle(cornerRadius: 14)
                                        .fill(BrandTheme.surfaceStrong)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(BrandTheme.outline, lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)

                            NavigationLink {
                                ManualEntriesView()
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: "list.bullet.clipboard")
                                        .font(.title3.weight(.semibold))
                                        .foregroundStyle(BrandTheme.ink)
                                        .frame(width: 36, height: 36)
                                        .background(
                                            RoundedRectangle(cornerRadius: 10)
                                                .fill(BrandTheme.ink.opacity(0.06))
                                        )
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Manual Sales Log")
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(BrandTheme.ink)
                                        Text("Review manually logged sales")
                                            .font(.caption)
                                            .foregroundStyle(BrandTheme.inkSoft)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(BrandTheme.inkSoft)
                                }
                                .padding(14)
                                .background(
                                    RoundedRectangle(cornerRadius: 14)
                                        .fill(BrandTheme.surfaceStrong)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(BrandTheme.outline, lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                            .vintageCard()
                        }

                        DashboardSection(title: "System", subtitle: "Environment and sync details") {
                            VStack(spacing: 0) {
                                settingsRow(label: "Timezone", value: "Europe/London")
                                Divider().overlay(BrandTheme.divider)
                                HStack {
                                    Text("Live Sync")
                                        .foregroundStyle(BrandTheme.inkSoft)
                                    Spacer()
                                    StatusPill(text: "Every 60s", tone: BrandTheme.success)
                                }
                                .padding(.vertical, 12)
                                Divider().overlay(BrandTheme.divider)
                                settingsRow(label: "App Version", value: appVersion)
                            }
                            .padding(.horizontal, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(BrandTheme.surfaceStrong)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(BrandTheme.outline, lineWidth: 1)
                            )
                            .vintageCard()
                        }

                        DashboardSection(title: "Calendar", subtitle: "Google Calendar connection") {
                            if calendarAuth.isSignedIn {
                                VStack(spacing: 10) {
                                    HStack(spacing: 12) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(BrandTheme.success)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("Connected")
                                                .font(.subheadline.weight(.semibold))
                                                .foregroundStyle(BrandTheme.ink)
                                            Text(calendarAuth.userEmail ?? "")
                                                .font(.caption)
                                                .foregroundStyle(BrandTheme.inkSoft)
                                        }
                                        Spacer()
                                    }
                                    .padding(14)
                                    .background(
                                        RoundedRectangle(cornerRadius: 14)
                                            .fill(BrandTheme.surfaceStrong)
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14)
                                            .stroke(BrandTheme.outline, lineWidth: 1)
                                    )

                                    Button {
                                        calendarAuth.signOut()
                                    } label: {
                                        HStack {
                                            Image(systemName: "xmark.circle")
                                            Text("Disconnect Google Calendar")
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
                                    .buttonStyle(.plain)
                                }
                                .vintageCard()
                            } else {
                                Button {
                                    Task { try? await calendarAuth.signIn() }
                                } label: {
                                    HStack(spacing: 12) {
                                        Image(systemName: "calendar.badge.plus")
                                            .font(.title3.weight(.semibold))
                                            .foregroundStyle(BrandTheme.ink)
                                            .frame(width: 36, height: 36)
                                            .background(
                                                RoundedRectangle(cornerRadius: 10)
                                                    .fill(BrandTheme.ink.opacity(0.06))
                                            )
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("Connect Google Calendar")
                                                .font(.subheadline.weight(.semibold))
                                                .foregroundStyle(BrandTheme.ink)
                                            Text("Sign in to sync store events")
                                                .font(.caption)
                                                .foregroundStyle(BrandTheme.inkSoft)
                                        }
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .font(.caption.weight(.bold))
                                            .foregroundStyle(BrandTheme.inkSoft)
                                    }
                                    .padding(14)
                                    .background(
                                        RoundedRectangle(cornerRadius: 14)
                                            .fill(BrandTheme.surfaceStrong)
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14)
                                            .stroke(BrandTheme.outline, lineWidth: 1)
                                    )
                                }
                                .buttonStyle(.plain)
                                .vintageCard()
                            }
                        }

                        if StaffDirectory.isAdmin(session.userName) {
                            DashboardSection(title: "Staff Management", subtitle: "Manage team access (admin only)") {
                                NavigationLink {
                                    StaffManagementView()
                                } label: {
                                    HStack(spacing: 12) {
                                        Image(systemName: "person.3.fill")
                                            .font(.title3.weight(.semibold))
                                            .foregroundStyle(BrandTheme.ink)
                                            .frame(width: 36, height: 36)
                                            .background(
                                                RoundedRectangle(cornerRadius: 10)
                                                    .fill(BrandTheme.ink.opacity(0.06))
                                            )
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("Staff & PINs")
                                                .font(.subheadline.weight(.semibold))
                                                .foregroundStyle(BrandTheme.ink)
                                            Text("Reset codes, add or remove people")
                                                .font(.caption)
                                                .foregroundStyle(BrandTheme.inkSoft)
                                        }
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .font(.caption.weight(.bold))
                                            .foregroundStyle(BrandTheme.inkSoft)
                                    }
                                    .padding(14)
                                    .background(
                                        RoundedRectangle(cornerRadius: 14)
                                            .fill(BrandTheme.surfaceStrong)
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14)
                                            .stroke(BrandTheme.outline, lineWidth: 1)
                                    )
                                }
                                .buttonStyle(.plain)
                                .vintageCard()
                            }
                        }

                        DashboardSection(title: "Account", subtitle: "User and access control") {
                            VStack(spacing: 10) {
                                Button {
                                    session.switchUser()
                                } label: {
                                    HStack {
                                        Image(systemName: "person.crop.circle.badge.arrow.right")
                                        Text("Switch User")
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
                                .buttonStyle(.plain)

                                Button {
                                    calendarAuth.signOut()
                                    session.signOut()
                                } label: {
                                    HStack {
                                        Image(systemName: "rectangle.portrait.and.arrow.right")
                                        Text("Sign Out")
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
                                .buttonStyle(.plain)
                            }
                            .vintageCard()
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .opacity(animateIn ? 1 : 0)
                    .offset(y: animateIn ? 0 : 8)
                }
            }
            .navigationTitle("Settings")
            .task {
                animateIn = false
                withAnimation(.spring(duration: 0.4, bounce: 0.18)) {
                    animateIn = true
                }
            }
        }
    }

    private var headerCard: some View {
        VStack(spacing: 16) {
            Image("fitsin-logo")
                .resizable()
                .scaledToFit()
                .frame(height: 132)

            VStack(spacing: 4) {
                if let name = session.userName {
                    Text("Signed in as \(name)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(BrandTheme.ink)
                }
                Text("Internal sales dashboard")
                    .font(.caption)
                    .foregroundStyle(BrandTheme.inkSoft)
            }

            HStack(spacing: 8) {
                StatusPill(text: "Secure", tone: BrandTheme.ink)
                StatusPill(text: "Live", tone: BrandTheme.success)
            }
        }
        .frame(maxWidth: .infinity)
        .vintageCard()
    }

    private func settingsRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(BrandTheme.inkSoft)
            Spacer()
            Text(value)
                .fontWeight(.semibold)
                .foregroundStyle(BrandTheme.ink)
        }
        .padding(.vertical, 12)
    }
}
