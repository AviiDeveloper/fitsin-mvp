import SwiftUI

struct EventsView: View {
    @StateObject private var vm = EventsViewModel()
    @State private var animateIn = false

    var body: some View {
        NavigationStack {
            ZStack {
                DashboardBackground()

                ScrollView {
                    VStack(spacing: 10) {

                        if vm.events.isEmpty {
                            Text("No upcoming events")
                                .font(.headline)
                                .foregroundStyle(BrandTheme.inkSoft)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .vintageCard()
                        }

                        ForEach(Array(vm.events.enumerated()), id: \.element.id) { index, event in
                            Link(destination: URL(string: event.url)!) {
                                HStack(alignment: .top, spacing: 12) {
                                    Image(systemName: "calendar.badge.clock")
                                        .font(.title3.weight(.semibold))
                                        .foregroundStyle(BrandTheme.accent)

                                    VStack(alignment: .leading, spacing: 6) {
                                        Text(event.title.isEmpty ? "Untitled Event" : event.title)
                                            .font(.headline)
                                            .foregroundStyle(BrandTheme.ink)
                                        if let date = event.date {
                                            Text(date)
                                                .font(.subheadline)
                                                .foregroundStyle(BrandTheme.inkSoft)
                                        }
                                        if let type = event.type, !type.isEmpty {
                                            Text(type.uppercased())
                                                .font(.caption.weight(.bold))
                                                .foregroundStyle(BrandTheme.accent)
                                        }
                                    }

                                    Spacer()
                                    Image(systemName: "arrow.up.right")
                                        .font(.subheadline.weight(.bold))
                                        .foregroundStyle(BrandTheme.inkSoft.opacity(0.75))
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .vintageCard()
                                .opacity(animateIn ? 1 : 0)
                                .offset(y: animateIn ? 0 : 10)
                                .animation(.easeOut(duration: 0.35).delay(Double(index) * 0.04), value: animateIn)
                            }
                        }

                        if let error = vm.errorText {
                            Text(error)
                                .font(.footnote)
                                .foregroundStyle(BrandTheme.inkSoft)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .vintageCard()
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .opacity(animateIn ? 1 : 0)
                    .offset(y: animateIn ? 0 : 10)
                }
                .refreshable {
                    await vm.load()
                }
            }
            .task {
                await vm.load()
                animateIn = false
                withAnimation(.spring(duration: 0.45, bounce: 0.2)) {
                    animateIn = true
                }
            }
            .navigationTitle("Events")
            .toolbarColorScheme(.light, for: .navigationBar)
        }
    }
}
