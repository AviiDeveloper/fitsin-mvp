import SwiftUI

struct DaySalesView: View {
    let date: String

    @StateObject private var vm = DaySalesViewModel()

    private var soldAtParser: ISO8601DateFormatter {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }

    private var soldAtFallbackParser: ISO8601DateFormatter {
        ISO8601DateFormatter()
    }

    private var soldAtFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        f.locale = Locale(identifier: "en_GB")
        f.timeZone = TimeZone(identifier: "Europe/London")
        return f
    }

    private var gbp: NumberFormatter {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = "GBP"
        f.locale = Locale(identifier: "en_GB")
        return f
    }

    var body: some View {
        ZStack {
            DashboardBackground()

            ScrollView {
                VStack(spacing: 12) {
                    if let payload = vm.payload {
                        if payload.items.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("No sales recorded")
                                    .font(.headline)
                                    .foregroundStyle(BrandTheme.ink)
                                Text("No Shopify or manual entries found for this day.")
                                    .font(.subheadline)
                                    .foregroundStyle(BrandTheme.inkSoft)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .vintageCard()
                        } else {
                            ForEach(payload.items) { item in
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack(alignment: .top) {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(formatTime(item.sold_at))
                                                .font(.caption.weight(.semibold))
                                                .foregroundStyle(BrandTheme.inkSoft)
                                            Text(item.description)
                                                .font(.subheadline.weight(.semibold))
                                                .foregroundStyle(BrandTheme.ink)
                                                .fixedSize(horizontal: false, vertical: true)
                                        }
                                        Spacer()
                                        VStack(alignment: .trailing, spacing: 2) {
                                            Text("x\(max(1, item.quantity))")
                                                .font(.caption)
                                                .foregroundStyle(BrandTheme.inkSoft)
                                            if let amount = item.amount {
                                                Text(gbp.string(from: NSNumber(value: amount)) ?? "£0")
                                                    .font(.caption.weight(.bold))
                                                    .foregroundStyle(BrandTheme.accent)
                                            }
                                        }
                                    }

                                    HStack(spacing: 6) {
                                        StatusPill(text: (item.kind == "manual" ? "MANUAL" : "SHOPIFY"), tone: item.kind == "manual" ? BrandTheme.success : BrandTheme.accent)
                                        if let orderName = item.order_name, !orderName.isEmpty {
                                            Text(orderName)
                                                .font(.caption)
                                                .foregroundStyle(BrandTheme.inkSoft)
                                        }
                                    }

                                    if let note = item.note, !note.isEmpty {
                                        Text("Note: \(note)")
                                            .font(.caption)
                                            .foregroundStyle(BrandTheme.inkSoft)
                                    }
                                }
                                .vintageCard()
                            }
                        }
                    } else {
                        ProgressView("Loading sales...")
                            .frame(maxWidth: .infinity, alignment: .center)
                            .vintageCard()
                    }

                    if let errorText = vm.errorText, !errorText.isEmpty {
                        InlineNotice(text: errorText, tone: BrandTheme.danger, systemImage: "exclamationmark.triangle.fill")
                            .vintageCard()
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
        }
        .navigationTitle(date)
        .task { await vm.load(date: date) }
        .refreshable { await vm.load(date: date) }
    }

    private func formatTime(_ iso: String) -> String {
        if let date = soldAtParser.date(from: iso) ?? soldAtFallbackParser.date(from: iso) {
            return soldAtFormatter.string(from: date)
        }
        return "--:--"
    }
}
