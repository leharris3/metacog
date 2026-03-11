import SwiftUI

struct InterventionOverlayView: View {
    @EnvironmentObject private var manager: InterventionManager
    @EnvironmentObject private var appState: AppState

    @State private var ankiUserAnswer = ""
    @State private var showAnswer = false
    @FocusState private var isAnswerFocused: Bool

    var body: some View {
        VStack(spacing: 24) {
            // Header
            Image(systemName: "hand.raised.fill")
                .font(.system(size: 36))
                .foregroundStyle(.orange)

            Text(appState.currentTask != nil ? "Unauthorized App Switch" : "No Task Declared")
                .font(.system(.title2, design: .rounded, weight: .bold))

            Text(appState.currentTask != nil
                 ? "You tried to switch to **\(manager.unauthorizedAppName)**, which isn't in your task's permitted apps."
                 : "You must declare a task before using **\(manager.unauthorizedAppName)** or any other app.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal)

            Divider()

            // Phase content
            switch manager.interventionPhase {
            case .timer:
                timerPhaseView
            case .anki:
                ankiPhaseView
            case .complete:
                EmptyView()
            }

            // Override button
            if manager.overridesRemaining > 0 {
                Button(action: { manager.useOverride() }) {
                    HStack {
                        Image(systemName: "forward.fill")
                        Text("Skip (\(manager.overridesRemaining) remaining today)")
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .foregroundStyle(.secondary)
            }
        }
        .padding(30)
        .frame(width: 480)
        .background(.ultraThickMaterial)
    }

    private var timerPhaseView: some View {
        VStack(spacing: 16) {
            Text("Wait before proceeding")
                .font(.headline)

            let total = appState.currentPenaltyDuration
            let progress = total > 0 ? max(0, 1 - manager.remainingPenalty / total) : 1

            Text(formatPenalty(manager.remainingPenalty))
                .font(.system(size: 48, weight: .bold, design: .monospaced))
                .foregroundStyle(.orange)

            ProgressView(value: progress)
                .tint(.orange)
        }
    }

    @ViewBuilder
    private var ankiPhaseView: some View {
        if let card = manager.currentAnkiCard {
            VStack(spacing: 16) {
                Text("Answer correctly to proceed")
                    .font(.headline)

                Text(card.front)
                    .font(.title3.weight(.medium))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
                    .fixedSize(horizontal: false, vertical: true)
                    .background(RoundedRectangle(cornerRadius: 10).fill(.background.opacity(0.5)))

                if !showAnswer {
                    TextField("Your answer…", text: $ankiUserAnswer)
                        .textFieldStyle(.roundedBorder)
                        .focused($isAnswerFocused)

                    Button("Reveal Answer") {
                        showAnswer = true
                    }
                    .buttonStyle(.bordered)
                } else {
                    VStack(spacing: 8) {
                        Text("Answer:")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                        Text(verbatim: card.back)
                            .font(.body)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .fixedSize(horizontal: false, vertical: true)
                            .background(RoundedRectangle(cornerRadius: 8).fill(.green.opacity(0.1)))
                    }

                    HStack(spacing: 16) {
                        Button("Incorrect") {
                            showAnswer = false
                            ankiUserAnswer = ""
                            manager.handleAnkiAnswer(correct: false)
                        }
                        .buttonStyle(.bordered)
                        .tint(.red)

                        Button("Correct") {
                            showAnswer = false
                            ankiUserAnswer = ""
                            manager.handleAnkiAnswer(correct: true)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            }
            .onAppear { isAnswerFocused = true }
        }
    }

    private func formatPenalty(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}
