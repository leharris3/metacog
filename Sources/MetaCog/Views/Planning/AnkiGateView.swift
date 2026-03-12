import SwiftUI

/// A single-card Anki challenge that must be answered before the user
/// can create a new task or project.
///
/// **Flow:**
/// 1. A random card is shown (due cards preferred, falls back to any card).
/// 2. User types their answer, then clicks "Reveal Answer".
/// 3. User self-grades as "Correct" or "Incorrect".
///    - Either way: card is updated via SM-2, gate dismisses, and the planning wizard opens.
/// 4. If no Anki cards exist, a message directs the user to add cards from the Dashboard.
///
/// The gate target (task vs. project) is stored in `AppState.ankiGateTarget` so that
/// on success, the correct wizard opens.
struct AnkiGateView: View {
    @EnvironmentObject private var appState: AppState

    @State private var currentCard: AnkiCard?
    @State private var userAnswer = ""
    @State private var showAnswer = false
    @State private var hasCards = true
    @FocusState private var isAnswerFocused: Bool

    var body: some View {
        VStack(spacing: 20) {
            // Header
            Image(systemName: "brain.head.profile")
                .font(.system(size: 32))
                .foregroundStyle(.tint)

            Text("Anki Challenge")
                .font(.system(.title3, design: .rounded, weight: .semibold))

            Text("Answer a flashcard to proceed.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Divider()

            if !hasCards {
                noCardsView
            } else if let card = currentCard {
                cardChallengeView(card: card)
            } else {
                ProgressView("Loading card…")
            }

            Spacer()

            // Cancel button
            Button("Cancel") {
                appState.showingAnkiGate = false
            }
            .foregroundStyle(.secondary)
        }
        .padding(24)
        .frame(width: 480, height: 440)
        .background(.ultraThinMaterial)
        .onAppear {
            loadCard()
        }
    }

    // MARK: - No Cards

    /// Shown when the user has no Anki cards — they must add cards before creating tasks.
    private var noCardsView: some View {
        VStack(spacing: 12) {
            Image(systemName: "rectangle.stack.badge.plus")
                .font(.system(size: 28))
                .foregroundStyle(.secondary)

            Text("No Anki cards found")
                .font(.headline)

            Text("Add flashcards from the Anki tab in the Dashboard before creating a task or project.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }

    // MARK: - Card Challenge

    /// The main Anki card challenge — mirrors the intervention flow.
    private func cardChallengeView(card: AnkiCard) -> some View {
        VStack(spacing: 16) {
            // Question
            Text(card.front)
                .font(.body.weight(.medium))
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding()
                .fixedSize(horizontal: false, vertical: true)
                .background(RoundedRectangle(cornerRadius: 10).fill(.background.opacity(0.5)))

            if !showAnswer {
                // Answer input
                TextField("Your answer…", text: $userAnswer)
                    .textFieldStyle(.roundedBorder)
                    .focused($isAnswerFocused)

                Button("Reveal Answer") {
                    showAnswer = true
                }
                .buttonStyle(.bordered)
            } else {
                // Revealed answer + grading buttons
                VStack(spacing: 8) {
                    Text("Answer:")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                    Text(verbatim: card.back)
                        .font(.callout)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .fixedSize(horizontal: false, vertical: true)
                        .background(RoundedRectangle(cornerRadius: 8).fill(.green.opacity(0.1)))
                }

                HStack(spacing: 16) {
                    Button("Incorrect") {
                        handleAnswer(correct: false)
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)

                    Button("Correct") {
                        handleAnswer(correct: true)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .onAppear { isAnswerFocused = true }
    }

    // MARK: - Logic

    /// Loads a random Anki card, preferring due cards.
    private func loadCard() {
        let allCards = (try? DatabaseManager.shared.fetchAllAnkiCards()) ?? []

        guard !allCards.isEmpty else {
            hasCards = false
            return
        }

        let dueCards = allCards.filter { $0.isDueForReview }
        currentCard = dueCards.randomElement() ?? allCards.randomElement()
        userAnswer = ""
        showAnswer = false
    }

    /// Handles the user's self-graded answer. The gate passes after a single prompt
    /// regardless of correctness — the card is still updated via SM-2.
    private func handleAnswer(correct: Bool) {
        guard var card = currentCard else { return }

        // Update card using the SM-2 algorithm (same quality ratings as interventions).
        card.review(quality: correct ? 4 : 1)
        try? DatabaseManager.shared.updateAnkiCard(card)

        // Gate passed — open the appropriate wizard.
        appState.showingAnkiGate = false
        switch appState.ankiGateTarget {
        case .task:
            appState.showingPlanningWizard = true
        case .project:
            appState.showingProjectWizard = true
        }
    }
}
