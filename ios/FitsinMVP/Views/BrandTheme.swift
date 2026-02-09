import SwiftUI

enum BrandTheme {
    static let paper = Color(red: 0.95, green: 0.95, blue: 0.94)
    static let paperSoft = Color(red: 0.90, green: 0.90, blue: 0.88)
    static let ink = Color(red: 0.09, green: 0.09, blue: 0.10)
    static let inkSoft = Color(red: 0.39, green: 0.38, blue: 0.40)
    static let accent = Color(red: 0.21, green: 0.37, blue: 0.52)
    static let success = Color(red: 0.14, green: 0.49, blue: 0.31)
    static let danger = Color(red: 0.74, green: 0.21, blue: 0.20)
    static let surface = Color.white.opacity(0.84)
    static let surfaceStrong = Color.white.opacity(0.96)
    static let outline = Color.black.opacity(0.09)
    static let divider = Color.black.opacity(0.08)
}

struct VintageCard: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(BrandTheme.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(BrandTheme.outline, lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.08), radius: 18, x: 0, y: 10)
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
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay(
            ZStack {
                RadialGradient(
                    colors: [
                        BrandTheme.accent.opacity(0.09),
                        .clear
                    ],
                    center: .topTrailing,
                    startRadius: 20,
                    endRadius: 420
                )
                RadialGradient(
                    colors: [
                        BrandTheme.ink.opacity(0.03),
                        .clear
                    ],
                    center: .bottomLeading,
                    startRadius: 20,
                    endRadius: 360
                )
            }
        )
        .overlay(
            Rectangle()
                .stroke(
                    LinearGradient(
                        colors: [BrandTheme.divider.opacity(0.45), .clear, BrandTheme.divider.opacity(0.45)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.5
                )
                .blendMode(.overlay)
                .padding(1)
        )
        .ignoresSafeArea()
    }
}

struct StatusPill: View {
    let text: String
    let tone: Color

    var body: some View {
        Text(text)
            .font(.caption.weight(.bold))
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
            VStack(alignment: .leading, spacing: 3) {
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
                .font(.title3.weight(.bold))
                .foregroundStyle(tone)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
            .font(.headline.weight(.semibold))
            .foregroundStyle(BrandTheme.ink)
    }
}
