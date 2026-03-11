import SwiftUI

struct ResumeTaskPrompt: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.largeTitle)
                .foregroundStyle(.yellow)

            Text("Interrupted Task")
                .font(.system(.title2, design: .rounded, weight: .bold))

            if let task = appState.currentTask {
                Text("You have an unfinished task: **\(task.title)**")
                    .multilineTextAlignment(.center)

                HStack(spacing: 16) {
                    Button("Abandon") {
                        appState.hasInterruptedTask = false
                        appState.abandonTask()
                        dismiss()
                    }
                    .foregroundStyle(.red)

                    Button("Resume") {
                        appState.hasInterruptedTask = false
                        appState.resumeTask()
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .padding(30)
        .frame(width: 380)
        .background(.ultraThinMaterial)
        .interactiveDismissDisabled()
    }
}
