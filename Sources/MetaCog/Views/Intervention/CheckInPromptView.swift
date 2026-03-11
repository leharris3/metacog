import SwiftUI

struct CheckInPromptView: View {
    let subGoalTitle: String
    let threshold: Double

    @EnvironmentObject private var scheduler: CheckInScheduler
    @EnvironmentObject private var appState: AppState

    @State private var isCompleted: Bool? = nil
    @State private var reflection = ""
    @State private var showMidTaskEditor = false

    var body: some View {
        VStack(spacing: 20) {
            // Header
            Image(systemName: "bell.badge.fill")
                .font(.system(size: 28))
                .foregroundStyle(.blue)

            Text("Check-In")
                .font(.system(.title3, design: .rounded, weight: .bold))

            Text("You're at \(Int(threshold * 100))% of the estimated time for:")
                .foregroundStyle(.secondary)
                .font(.callout)

            Text(subGoalTitle)
                .font(.headline)
                .multilineTextAlignment(.center)

            Divider()

            Text("Have you completed this sub-goal?")
                .font(.subheadline)

            HStack(spacing: 16) {
                Button(action: { isCompleted = true }) {
                    Label("Yes", systemImage: "checkmark.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(isCompleted == true ? .green : nil)

                Button(action: { isCompleted = false }) {
                    Label("No", systemImage: "xmark.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(isCompleted == false ? .red : nil)
            }

            if isCompleted == false {
                TextField("What's blocking you?", text: $reflection, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(2...4)

                HStack(spacing: 12) {
                    // Continue with current subtasks without amending
                    Button("Keep Working") {
                        scheduler.completeCheckIn(
                            isCompleted: false,
                            reflection: reflection.isEmpty ? nil : reflection,
                            amendments: nil
                        )
                    }
                    .buttonStyle(.borderedProminent)

                    // Open the editor to change subtasks
                    Button("Amend Goals") {
                        showMidTaskEditor = true
                    }
                    .buttonStyle(.bordered)
                }
            }

            if isCompleted == true {
                Button("Submit") {
                    scheduler.completeCheckIn(
                        isCompleted: true,
                        reflection: nil,
                        amendments: nil
                    )
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
        .frame(width: 420, height: 360)
        .background(.ultraThinMaterial)
        .sheet(isPresented: $showMidTaskEditor) {
            MidTaskEditorView()
                .environmentObject(appState)
        }
    }
}
