import Foundation

@MainActor
final class SellerSalesViewModel: ObservableObject {
    @Published var sellers: [SellerSummary] = []
    @Published var items: [SellerItem] = []
    @Published var commissionRate: Double = 0.15
    @Published var selectedSeller: String?
    @Published var errorText: String?
    @Published var isLoading = false

    private static let monthFormatter: DateFormatter = {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM"
        fmt.timeZone = TimeZone(identifier: "Europe/London")
        return fmt
    }()

    var currentMonthKey: String {
        Self.monthFormatter.string(from: Date())
    }

    var filteredItems: [SellerItem] {
        guard let seller = selectedSeller else { return items }
        return items.filter { $0.seller == seller }
    }

    func load(month: String? = nil) async {
        isLoading = true
        defer { isLoading = false }

        do {
            let response = try await APIClient.shared.getSellerSales(month: month ?? currentMonthKey)
            sellers = response.sellers
            items = response.items
            commissionRate = response.commission_rate
            errorText = nil
        } catch {
            errorText = "Could not load seller sales."
        }
    }
}
