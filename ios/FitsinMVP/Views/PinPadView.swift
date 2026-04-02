import SwiftUI

struct PinPadView: View {
    @Binding var pin: String
    let length: Int
    let onComplete: () -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 20), count: 3)

    var body: some View {
        VStack(spacing: 28) {
            // Dot indicators
            HStack(spacing: 16) {
                ForEach(0..<length, id: \.self) { index in
                    Circle()
                        .fill(index < pin.count ? BrandTheme.ink : BrandTheme.ink.opacity(0.1))
                        .frame(width: 16, height: 16)
                        .animation(.easeOut(duration: 0.15), value: pin.count)
                }
            }
            .padding(.bottom, 8)

            // Number pad
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(1...9, id: \.self) { num in
                    numberButton("\(num)")
                }

                Color.clear.frame(height: 80)

                numberButton("0")

                Button {
                    if !pin.isEmpty {
                        pin.removeLast()
                    }
                } label: {
                    Image(systemName: "delete.backward")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundStyle(BrandTheme.ink)
                        .frame(height: 80)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func numberButton(_ digit: String) -> some View {
        Button {
            guard pin.count < length else { return }
            pin += digit
            if pin.count == length {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    onComplete()
                }
            }
        } label: {
            Text(digit)
                .font(.system(size: 35, weight: .medium, design: .rounded))
                .foregroundStyle(BrandTheme.ink)
                .frame(width: 80, height: 80)
                .background(
                    Circle()
                        .fill(BrandTheme.ink.opacity(0.04))
                )
        }
        .buttonStyle(.plain)
    }
}
