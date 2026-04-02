import SwiftUI

struct PinLockView: View {
    @EnvironmentObject var session: AppSession
    @State private var pinInput = ""
    @State private var errorText: String?
    @State private var shake = false
    @State private var animateIn = false

    var body: some View {
        ZStack {
            DashboardBackground()

            VStack(spacing: 28) {
                Spacer()

                Image("fitsin-logo")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 144)

                VStack(spacing: 6) {
                    Text("Welcome back, \(session.userName ?? "")")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(BrandTheme.ink)

                    if let error = errorText {
                        Text(error)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(BrandTheme.danger)
                            .transition(.opacity)
                    } else {
                        Text("Enter your PIN")
                            .font(.caption)
                            .foregroundStyle(BrandTheme.inkSoft)
                    }
                }

                PinPadView(pin: $pinInput, length: 6) {
                    verifyPin()
                }
                .offset(x: shake ? -8 : 0)
                .padding(.horizontal, 40)

                Button {
                    session.switchUser()
                } label: {
                    Text("Not \(session.userName ?? "you")? Switch user")
                        .font(.caption)
                        .foregroundStyle(BrandTheme.inkSoft)
                }
                .buttonStyle(.plain)

                Spacer()
            }
            .opacity(animateIn ? 1 : 0)
            .padding(20)
        }
        .task {
            animateIn = false
            withAnimation(.easeOut(duration: 0.4)) {
                animateIn = true
            }
        }
    }

    private func verifyPin() {
        if StaffDirectory.verify(name: session.userName ?? "", pin: pinInput) {
            session.verifyPin()
        } else {
            errorText = "Wrong PIN"
            pinInput = ""
            withAnimation(.default.repeatCount(3, autoreverses: true).speed(6)) {
                shake = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                shake = false
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                withAnimation { errorText = nil }
            }
        }
    }
}
