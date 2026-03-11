import SwiftUI
import Charts

struct AnalyticsPageView: View {
    @State private var totalActiveTime: TimeInterval = 0
    @State private var tasksCompleted = 0
    @State private var percentChange: Double = 0
    @State private var interventionCount = 0
    @State private var dailyData: [(day: String, hours: Double)] = []

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Summary cards
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    StatCard(
                        title: "Active Time",
                        value: formatHours(totalActiveTime),
                        icon: "clock.fill"
                    )
                    StatCard(
                        title: "Tasks Completed",
                        value: "\(tasksCompleted)",
                        icon: "checkmark.circle.fill"
                    )
                    StatCard(
                        title: "vs Last Week",
                        value: String(format: "%+.0f%%", percentChange),
                        icon: percentChange >= 0 ? "arrow.up.right" : "arrow.down.right",
                        valueColor: percentChange >= 0 ? .green : .red
                    )
                    StatCard(
                        title: "Interventions",
                        value: "\(interventionCount)",
                        icon: "hand.raised.fill"
                    )
                }

                // Bar chart
                VStack(alignment: .leading) {
                    Text("Daily Active Time")
                        .font(.headline)
                        .padding(.leading, 4)

                    if dailyData.isEmpty {
                        ContentUnavailableView(
                            "No Data Yet",
                            systemImage: "chart.bar",
                            description: Text("Complete tasks to see your weekly activity.")
                        )
                        .frame(height: 200)
                    } else {
                        Chart(dailyData, id: \.day) { item in
                            BarMark(
                                x: .value("Day", item.day),
                                y: .value("Hours", item.hours)
                            )
                            .foregroundStyle(Color.accentColor.gradient)
                            .cornerRadius(4)
                        }
                        .chartYAxisLabel("Hours")
                        .frame(height: 200)
                    }
                }
                .padding()
                .background(RoundedRectangle(cornerRadius: 12).fill(.background.opacity(0.5)))
            }
            .padding(20)
        }
        .onAppear(perform: loadData)
    }

    private func loadData() {
        let db = DatabaseManager.shared
        totalActiveTime = (try? db.fetchTotalActiveTimeThisWeek()) ?? 0
        tasksCompleted = (try? db.fetchTasksCompletedThisWeek().count) ?? 0
        interventionCount = (try? db.fetchInterventionsThisWeek().count) ?? 0

        let rawDaily = (try? db.fetchDailyActiveTime()) ?? []
        dailyData = rawDaily.map { (day: $0.date, hours: $0.duration / 3600) }

        // Calculate percent change vs last week
        let calendar = Calendar.current
        let lastWeek = calendar.date(byAdding: .weekOfYear, value: -1, to: Date()) ?? Date()
        let lastWeekData = (try? db.fetchDailyActiveTime(for: lastWeek)) ?? []
        let lastWeekTotal = lastWeekData.reduce(0.0) { $0 + $1.duration }
        if lastWeekTotal > 0 {
            percentChange = ((totalActiveTime - lastWeekTotal) / lastWeekTotal) * 100
        } else {
            percentChange = totalActiveTime > 0 ? 100 : 0
        }
    }

    private func formatHours(_ interval: TimeInterval) -> String {
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60
        return "\(hours)h \(minutes)m"
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    var valueColor: Color = .primary

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(.secondary)
                    .font(.caption)
                Spacer()
            }
            Text(value)
                .font(.system(.title2, design: .rounded, weight: .bold))
                .foregroundStyle(valueColor)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 10).fill(.background.opacity(0.5)))
    }
}
