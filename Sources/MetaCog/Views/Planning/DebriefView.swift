import SwiftUI

struct DebriefView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var outcome: DebriefOutcome = .partial
    @State private var reflections: [SubGoalReflectionEntry] = []
    @State private var lessonsLearned = ""

    var body: some View {
        VStack(spacing: 0) {
            Text("Task Debrief")
                .font(.system(.title2, design: .rounded, weight: .bold))
                .padding(.top, 20)

            if let task = appState.currentTask {
                Text(task.title)
                    .font(.headline)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Sub-goal reflections
                    if !reflections.isEmpty {
                        Text("Sub-Goal Review")
                            .font(.headline)

                        ForEach($reflections) { $entry in
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text(entry.title)
                                        .font(.subheadline.weight(.medium))
                                    Spacer()
                                    Toggle("Completed", isOn: $entry.wasCompleted)
                                        .toggleStyle(.switch)
                                        .labelsHidden()
                                }
                                if !entry.wasCompleted {
                                    TextField("What happened?", text: $entry.explanation, axis: .vertical)
                                        .textFieldStyle(.roundedBorder)
                                        .lineLimit(2...4)
                                }
                            }
                            .padding(10)
                            .background(RoundedRectangle(cornerRadius: 8).fill(.background.opacity(0.5)))
                        }
                    }

                    // Overall outcome
                    Text("Overall Outcome")
                        .font(.headline)

                    Picker("Outcome", selection: $outcome) {
                        ForEach(DebriefOutcome.allCases, id: \.self) { o in
                            Text(o.rawValue.capitalized).tag(o)
                        }
                    }
                    .pickerStyle(.segmented)

                    // Lessons learned
                    Text("Reflections")
                        .font(.headline)

                    TextEditor(text: $lessonsLearned)
                        .frame(minHeight: 80)
                        .scrollContentBackground(.hidden)
                        .padding(8)
                        .background(RoundedRectangle(cornerRadius: 8).fill(.background))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(.quaternary))
                }
                .padding(20)
            }

            Button("Complete Debrief") {
                saveDebrief()
            }
            .buttonStyle(.borderedProminent)
            .padding(20)
            .disabled(lessonsLearned.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .frame(width: 520, height: 560)
        .background(.ultraThinMaterial)
        .onAppear {
            reflections = appState.subGoals.map { sg in
                SubGoalReflectionEntry(
                    subGoalId: sg.id,
                    title: sg.title,
                    wasCompleted: sg.isCompleted,
                    explanation: ""
                )
            }
        }
        .interactiveDismissDisabled()
    }

    private func saveDebrief() {
        guard let task = appState.currentTask else { return }

        let subGoalReflections = reflections.map { entry in
            SubGoalReflection(
                subGoalId: entry.subGoalId,
                wasCompleted: entry.wasCompleted,
                explanation: entry.explanation
            )
        }

        let debrief = TaskDebrief(
            taskId: task.id,
            overallOutcome: outcome,
            subGoalReflections: subGoalReflections,
            lessonsLearned: lessonsLearned
        )

        try? DatabaseManager.shared.createDebrief(debrief)
        appState.finalizeDebrief(outcome: outcome)
        dismiss()
    }
}

struct SubGoalReflectionEntry: Identifiable {
    let id = UUID()
    var subGoalId: UUID
    var title: String
    var wasCompleted: Bool
    var explanation: String
}
