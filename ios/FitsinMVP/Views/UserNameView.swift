import SwiftUI

struct UserNameView: View {
    @EnvironmentObject var session: AppSession
    @State private var selectedName: String?
    @State private var pinInput = ""
    @State private var showPinEntry = false
    @State private var isNewUser = false
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

                if showPinEntry {
                    pinEntrySection
                } else {
                    namePickerSection
                }

                Spacer()
            }
            .opacity(animateIn ? 1 : 0)
            .padding(20)
        }
        .task {
            animateIn = false
            withAnimation(.spring(duration: 0.5, bounce: 0.15)) {
                animateIn = true
            }
        }
    }

    // MARK: - Name Picker

    private var namePickerSection: some View {
        VStack(spacing: 16) {
            VStack(spacing: 4) {
                Text("Who's here?")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(BrandTheme.ink)
                Text("Tap your name")
                    .font(.caption)
                    .foregroundStyle(BrandTheme.inkSoft)
            }

            VStack(spacing: 8) {
                ForEach(StaffDirectory.allNames, id: \.self) { name in
                    Button {
                        selectedName = name
                        pinInput = ""
                        errorText = nil

                        withAnimation(.spring(duration: 0.3)) {
                            isNewUser = !StaffDirectory.hasPin(name)
                            showPinEntry = true
                        }
                    } label: {
                        Text(name)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(BrandTheme.ink)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(BrandTheme.ink.opacity(0.04))
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - PIN Entry

    private var pinEntrySection: some View {
        VStack(spacing: 20) {
            VStack(spacing: 6) {
                Text(isNewUser ? "Hi, \(selectedName ?? "")!" : selectedName ?? "")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(BrandTheme.ink)

                if let error = errorText {
                    Text(error)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(BrandTheme.danger)
                        .transition(.opacity)
                } else {
                    Text(isNewUser ? "Choose a 6-digit PIN" : "Enter your PIN")
                        .font(.caption)
                        .foregroundStyle(BrandTheme.inkSoft)
                }
            }

            PinPadView(pin: $pinInput, length: 6) {
                handlePinComplete()
            }
            .offset(x: shake ? -8 : 0)
            .padding(.horizontal, 40)

            if isNewUser {
                Text("You'll need this PIN every time you open the app.")
                    .font(.system(size: 11))
                    .foregroundStyle(BrandTheme.inkSoft)
                    .multilineTextAlignment(.center)
            }

            Button {
                withAnimation(.spring(duration: 0.3)) {
                    showPinEntry = false
                    isNewUser = false
                    errorText = nil
                    pinInput = ""
                }
            } label: {
                Text("Back")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(BrandTheme.inkSoft)
            }
            .buttonStyle(.plain)
        }
    }

    private func handlePinComplete() {
        if isNewUser {
            StaffDirectory.setPin(pinInput, for: selectedName ?? "")
            session.saveName(selectedName ?? "")
        } else {
            if StaffDirectory.verify(name: selectedName ?? "", pin: pinInput) {
                session.saveName(selectedName ?? "")
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
}
