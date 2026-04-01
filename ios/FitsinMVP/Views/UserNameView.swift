import SwiftUI

struct UserNameView: View {
    @EnvironmentObject var session: AppSession
    @State private var name = ""
    @State private var animateIn = false

    var body: some View {
        NavigationStack {
            ZStack {
                DashboardBackground()

                VStack(spacing: 24) {
                    Image("fitsin-logo")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 60)
                        .foregroundStyle(BrandTheme.ink)

                    VStack(alignment: .leading, spacing: 14) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Who's using the app?")
                                .font(.title2.bold())
                                .foregroundStyle(BrandTheme.ink)
                            Text("Enter your name so we know who you are")
                                .font(.subheadline)
                                .foregroundStyle(BrandTheme.inkSoft)
                        }

                        TextField("Your name", text: $name)
                            .textInputAutocapitalization(.words)
                            .autocorrectionDisabled()
                            .textFieldStyle(FitsinInputStyle())

                        Button {
                            session.saveName(name)
                        } label: {
                            Text("Continue")
                                .font(.subheadline.weight(.semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 13)
                                .background(
                                    RoundedRectangle(cornerRadius: 14)
                                        .fill(trimmedName.isEmpty ? BrandTheme.ink.opacity(0.3) : BrandTheme.ink)
                                )
                                .foregroundStyle(.white)
                        }
                        .disabled(trimmedName.isEmpty)
                    }
                    .vintageCard()
                }
                .opacity(animateIn ? 1 : 0)
                .offset(y: animateIn ? 0 : 12)
                .padding(20)
            }
            .task {
                animateIn = false
                withAnimation(.spring(duration: 0.5, bounce: 0.15)) {
                    animateIn = true
                }
            }
        }
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
