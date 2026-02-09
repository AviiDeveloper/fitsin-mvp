import SwiftUI

enum BrandTheme {
    static let paper = Color(red: 0.96, green: 0.96, blue: 0.95)
    static let paperSoft = Color(red: 0.92, green: 0.92, blue: 0.90)
    static let ink = Color(red: 0.10, green: 0.11, blue: 0.13)
    static let inkSoft = Color(red: 0.39, green: 0.40, blue: 0.41)
    static let accent = Color(red: 0.18, green: 0.42, blue: 0.57)
    static let success = Color(red: 0.16, green: 0.48, blue: 0.33)
    static let danger = Color(red: 0.74, green: 0.23, blue: 0.21)
    static let surface = Color.white.opacity(0.86)
    static let surfaceStrong = Color.white.opacity(0.95)
    static let outline = Color.black.opacity(0.08)
    static let topBar = Color.black
    static let stripBg = Color(red: 0.84, green: 0.90, blue: 0.95)
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
            RadialGradient(
                colors: [
                    BrandTheme.accent.opacity(0.12),
                    .clear
                ],
                center: .topTrailing,
                startRadius: 20,
                endRadius: 420
            )
        )
        .ignoresSafeArea()
    }
}

struct BrandHeaderStrip: View {
    var body: some View {
        VStack(spacing: 0) {
            Text("BUY • SELL • TRADE")
                .font(.caption.weight(.bold))
                .foregroundStyle(Color.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(BrandTheme.topBar)

            Text("CURATED VINTAGE & ARCHIVE STREETWEAR — ONE OF ONE PIECES — NO RESTOCKS")
                .font(.caption2.weight(.bold))
                .foregroundStyle(BrandTheme.ink)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(BrandTheme.stripBg)
        }
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
