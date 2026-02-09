import SwiftUI

struct AccessCodeView: View {
    @EnvironmentObject var session: AppSession
    @State private var code = ""
    @State private var animateIn = false

    var body: some View {
        NavigationStack {
            ZStack {
                DashboardBackground()

                VStack(spacing: 14) {

                    VStack(alignment: .leading, spacing: 10) {
                        Text("fit'sin")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(BrandTheme.inkSoft)
                        Text("Staff Dashboard Access")
                            .font(.title2.bold())
                            .foregroundStyle(BrandTheme.ink)
                        Text("Enter the shared team code")
                            .font(.subheadline)
                            .foregroundStyle(BrandTheme.inkSoft)

                        SecureField("Shared code", text: $code)
                            .textInputAutocapitalization(.never)
                            .padding(10)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(BrandTheme.surfaceStrong)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(BrandTheme.outline, lineWidth: 1)
                            )

                        Button {
                            session.save(code: code)
                        } label: {
                            Text("Enter Dashboard")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 11)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(code.isEmpty ? BrandTheme.ink.opacity(0.35) : BrandTheme.ink)
                                )
                                .foregroundStyle(.white)
                        }
                        .disabled(code.isEmpty)
                    }
                    .vintageCard()
                    .opacity(animateIn ? 1 : 0)
                    .offset(y: animateIn ? 0 : 8)

                    Text("This app uses one shared staff code and no individual accounts.")
                        .font(.footnote)
                        .foregroundStyle(BrandTheme.inkSoft)
                }
                .padding(18)
            }
            .task {
                animateIn = false
                withAnimation(.spring(duration: 0.4, bounce: 0.18)) {
                    animateIn = true
                }
            }
        }
    }
}
