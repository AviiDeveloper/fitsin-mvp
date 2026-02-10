import Foundation

@MainActor
final class DaySalesViewModel: ObservableObject {
    @Published var payload: DaySalesResponse?
    @Published var errorText: String?

    func load(date: String) async {
        do {
            let data = try await APIClient.shared.getDaySales(date: date)
            payload = data
            errorText = data.warning
        } catch {
            errorText = "Could not load day sales."
        }
    }
}
