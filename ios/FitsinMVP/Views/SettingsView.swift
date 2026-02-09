import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var session: AppSession
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

                        DashboardSection(title: "Admin", subtitle: "Data and internal controls") {
                            NavigationLink {
                                ManualEntriesView()
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: "list.bullet.clipboard")
                                        .font(.title3.weight(.semibold))
                                        .foregroundStyle(BrandTheme.accent)
                                        .frame(width: 34, height: 34)
                                        .background(
                                            RoundedRectangle(cornerRadius: 10)
                                                .fill(BrandTheme.accent.opacity(0.14))
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
                                .padding(12)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(BrandTheme.surfaceStrong)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
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
                                    StatusPill(text: "Every 15s", tone: BrandTheme.success)
                                }
                                .padding(.vertical, 12)
                                Divider().overlay(BrandTheme.divider)
                                settingsRow(label: "App Version", value: appVersion)
                            }
                            .padding(.horizontal, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(BrandTheme.surfaceStrong)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(BrandTheme.outline, lineWidth: 1)
                            )
                            .vintageCard()
                        }

                        DashboardSection(title: "Security", subtitle: "Shared-code access control") {
                            Button {
                                session.signOut()
                            } label: {
                                HStack {
                                    Image(systemName: "rectangle.portrait.and.arrow.right")
                                    Text("Clear Access Code")
                                        .font(.subheadline.weight(.semibold))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 11)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(BrandTheme.danger.opacity(0.12))
                                )
                                .foregroundStyle(BrandTheme.danger)
                            }
                            .buttonStyle(.plain)
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
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("fit'sin Dashboard")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(BrandTheme.ink)
                Text("Internal sales operations")
                    .font(.subheadline)
                    .foregroundStyle(BrandTheme.inkSoft)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 6) {
                StatusPill(text: "Secure Access", tone: BrandTheme.accent)
                StatusPill(text: "Live Data", tone: BrandTheme.success)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .vintageCard()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        colors: [BrandTheme.surfaceStrong, BrandTheme.surface],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
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
