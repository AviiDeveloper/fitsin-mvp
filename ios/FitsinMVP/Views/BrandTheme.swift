import SwiftUI

enum BrandTheme {
    static let paper = Color(red: 0.95, green: 0.95, blue: 0.94)
    static let paperSoft = Color(red: 0.92, green: 0.92, blue: 0.91)
    static let ink = Color(red: 0.10, green: 0.11, blue: 0.12)
    static let inkSoft = Color(red: 0.38, green: 0.39, blue: 0.40)
    static let accent = Color(red: 0.18, green: 0.36, blue: 0.53)
    static let success = Color(red: 0.16, green: 0.47, blue: 0.30)
    static let danger = Color(red: 0.74, green: 0.20, blue: 0.20)
    static let surface = Color.white.opacity(0.76)
    static let surfaceStrong = Color.white.opacity(0.92)
    static let outline = Color.black.opacity(0.10)
    static let divider = Color.black.opacity(0.08)
}

struct VintageCard: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(BrandTheme.surfaceStrong)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(BrandTheme.outline, lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.06), radius: 14, x: 0, y: 8)
    }
}

extension View {
    func vintageCard() -> some View {
        modifier(VintageCard())
    }
}

struct DashboardBackground: View {
    var body: some View {
        LinearGradient(
            colors: [BrandTheme.paper, BrandTheme.paperSoft],
            startPoint: .top,
            endPoint: .bottom
        )
        .overlay(
            VStack(spacing: 0) {
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [BrandTheme.ink.opacity(0.06), .clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(height: 140)
                Spacer(minLength: 0)
            }
            .ignoresSafeArea()
        )
        .overlay(
            RadialGradient(
                colors: [BrandTheme.accent.opacity(0.06), .clear],
                center: .topTrailing,
                startRadius: 12,
                endRadius: 420
            )
        )
        .ignoresSafeArea()
    }
}

struct StatusPill: View {
    let text: String
    let tone: Color

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .tracking(0.35)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                Capsule()
                    .fill(tone.opacity(0.14))
            )
            .foregroundStyle(tone)
    }
}

struct DashboardSection<Content: View>: View {
    let title: String
    let subtitle: String?
    @ViewBuilder let content: Content

    init(title: String, subtitle: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .sectionHeaderStyle()
                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(BrandTheme.inkSoft)
                }
            }
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct StatTile: View {
    let title: String
    let value: String
    let tone: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(BrandTheme.inkSoft)
            Text(value)
                .font(.system(size: 21, weight: .bold, design: .rounded))
                .foregroundStyle(tone)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(BrandTheme.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(BrandTheme.outline, lineWidth: 1)
        )
    }
}

struct InlineNotice: View {
    let text: String
    let tone: Color
    let systemImage: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: systemImage)
                .foregroundStyle(tone)
                .font(.subheadline.weight(.semibold))
            Text(text)
                .font(.footnote)
                .foregroundStyle(BrandTheme.inkSoft)
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(tone.opacity(0.08))
        )
    }
}

extension View {
    func sectionHeaderStyle() -> some View {
        self
            .font(.system(size: 18, weight: .semibold, design: .rounded))
            .foregroundStyle(BrandTheme.ink)
    }
}
