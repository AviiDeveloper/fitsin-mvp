import SwiftUI

struct AccessCodeView: View {
    @EnvironmentObject var session: AppSession
    @State private var code = ""

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [BrandTheme.paper, BrandTheme.paperSoft],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                VStack(spacing: 14) {

                    VStack(alignment: .leading, spacing: 10) {
                        Text("fit'sin Access")
                            .font(.title.bold())
                            .foregroundStyle(BrandTheme.ink)
                        Text("Enter the shared team code")
                            .font(.subheadline)
                            .foregroundStyle(BrandTheme.inkSoft)

                        SecureField("Shared code", text: $code)
                            .textFieldStyle(.roundedBorder)

                        Button("Enter Dashboard") {
                            session.save(code: code)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(BrandTheme.accent)
                        .disabled(code.isEmpty)
                    }
                    .vintageCard()

                    Text("This app uses one shared staff code and no individual accounts.")
                        .font(.footnote)
                        .foregroundStyle(BrandTheme.inkSoft)
                }
                .padding(18)
            }
        }
    }
}
