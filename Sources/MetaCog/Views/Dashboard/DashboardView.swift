import SwiftUI

enum DashboardPage: Int, CaseIterable {
    case analytics
    case ledger
    case anki
    case database

    var icon: String {
        switch self {
        case .analytics: "chart.bar.fill"
        case .ledger: "list.bullet.rectangle.fill"
        case .anki: "rectangle.on.rectangle.fill"
        case .database: "tablecells"
        }
    }

    var label: String {
        switch self {
        case .analytics: "Analytics"
        case .ledger: "Tasks"
        case .anki: "Cards"
        case .database: "Database"
        }
    }
}

struct DashboardView: View {
    @EnvironmentObject private var appState: AppState
    @State private var selectedPage: DashboardPage = .analytics

    var body: some View {
        VStack(spacing: 0) {
            navBar
            contentView
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .background(.ultraThinMaterial)
    }

    private var navBar: some View {
        HStack {
            ForEach(DashboardPage.allCases, id: \.self) { page in
                Button(action: { selectedPage = page }) {
                    Image(systemName: page.icon)
                        .font(.system(size: 14))
                        .foregroundStyle(selectedPage == page ? Color.accentColor : Color.secondary)
                        .frame(width: 32, height: 32)
                        .background(
                            selectedPage == page
                                ? AnyShapeStyle(Color.accentColor.opacity(0.15))
                                : AnyShapeStyle(.clear)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
                .help(page.label)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
    }

    @ViewBuilder
    private var contentView: some View {
        switch selectedPage {
        case .analytics:
            AnalyticsPageView()
        case .ledger:
            TaskLedgerPageView()
        case .anki:
            AnkiPageView()
        case .database:
            DatabaseBrowserView()
        }
    }
}
