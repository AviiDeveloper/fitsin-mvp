import SwiftUI

enum BrandTheme {
    // MARK: - Brand Palette
    static let paper = Color(red: 0.96, green: 0.94, blue: 0.92)       // #F5F0EB warm cream
    static let paperSoft = Color(red: 0.93, green: 0.91, blue: 0.89)   // #EDE8E3 deeper cream
    static let ink = Color(red: 0.10, green: 0.10, blue: 0.10)         // #1A1A1A near-black
    static let inkSoft = Color(red: 0.55, green: 0.52, blue: 0.50)     // #8C8580 warm grey
    static let accent = Color(red: 0.77, green: 0.71, blue: 0.83)      // #C4B5D4 muted lavender
    static let success = Color(red: 0.18, green: 0.42, blue: 0.31)     // #2D6A4F forest green
    static let danger = Color(red: 0.74, green: 0.23, blue: 0.23)      // #BE3B3B brick red
    static let surface = Color.white.opacity(0.82)
    static let surfaceStrong = Color.white.opacity(0.95)
    static let outline = Color.black.opacity(0.08)
    static let divider = Color.black.opacity(0.06)
}

// MARK: - Card Modifier

struct VintageCard: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(BrandTheme.surfaceStrong)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(BrandTheme.outline, lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.04), radius: 16, x: 0, y: 6)
    }
}

extension View {
    func vintageCard() -> some View {
        modifier(VintageCard())
    }
}

// MARK: - Background

struct DashboardBackground: View {
    var body: some View {
        LinearGradient(
            colors: [BrandTheme.paper, BrandTheme.paperSoft],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
}

// MARK: - Status Pill

struct StatusPill: View {
    let text: String
    let tone: Color

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .bold, design: .rounded))
            .tracking(0.5)
            .textCase(.uppercase)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                Capsule()
                    .fill(tone.opacity(0.12))
            )
            .foregroundStyle(tone)
    }
}

// MARK: - Dashboard Section

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
        VStack(alignment: .leading, spacing: 12) {
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

// MARK: - Stat Tile

struct StatTile: View {
    let title: String
    let value: String
    let tone: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .tracking(0.8)
                .foregroundStyle(BrandTheme.inkSoft)
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(tone)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(BrandTheme.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(BrandTheme.outline, lineWidth: 1)
        )
    }
}

// MARK: - Inline Notice

struct InlineNotice: View {
    let text: String
    let tone: Color
    let systemImage: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: systemImage)
                .foregroundStyle(tone)
                .font(.subheadline.weight(.semibold))
            Text(text)
                .font(.footnote)
                .foregroundStyle(BrandTheme.inkSoft)
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(tone.opacity(0.06))
        )
    }
}

// MARK: - Typography

extension View {
    func sectionHeaderStyle() -> some View {
        self
            .font(.system(size: 18, weight: .bold, design: .rounded))
            .foregroundStyle(BrandTheme.ink)
    }
}
