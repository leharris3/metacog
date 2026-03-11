import SwiftUI
import Charts

struct AnkiPageView: View {
    @State private var cards: [AnkiCard] = []
    @State private var showingAddCard = false
    @State private var editingCard: AnkiCard?
    @State private var showingStudySession = false
    @State private var cardToDelete: AnkiCard?

    var body: some View {
        VStack(spacing: 0) {
            // Stats
            HStack(spacing: 16) {
                StatCard(title: "Total Cards", value: "\(cards.count)", icon: "rectangle.on.rectangle")
                StatCard(title: "Due Today", value: "\(dueCount)", icon: "clock.badge.exclamationmark")
                StatCard(title: "Avg Accuracy", value: accuracyString, icon: "target")
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)

            // Interval distribution chart
            if !cards.isEmpty {
                VStack(alignment: .leading) {
                    Text("Interval Distribution")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)

                    Chart(intervalDistribution, id: \.bucket) { item in
                        BarMark(
                            x: .value("Interval", item.bucket),
                            y: .value("Count", item.count)
                        )
                        .foregroundStyle(Color.accentColor.gradient)
                        .cornerRadius(3)
                    }
                    .frame(height: 80)
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
            }

            Divider()
                .padding(.top, 12)

            // Card management
            HStack {
                Text("Flash Cards")
                    .font(.headline)
                Spacer()

                if dueCount > 0 {
                    Button(action: { showingStudySession = true }) {
                        Label("Study Now", systemImage: "play.fill")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }

                Button(action: { showingAddCard = true }) {
                    Image(systemName: "plus")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)

            if cards.isEmpty {
                ContentUnavailableView(
                    "No Flash Cards",
                    systemImage: "rectangle.on.rectangle",
                    description: Text("Create cards to use during interventions and study sessions.")
                )
                .frame(height: 200)
            } else {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 200))], spacing: 10) {
                        ForEach(cards) { card in
                            AnkiCardCell(card: card, onEdit: {
                                editingCard = card
                            }, onDelete: {
                                cardToDelete = card
                            })
                        }
                    }
                    .padding(20)
                }
            }
        }
        .onAppear { reloadCards() }
        .sheet(isPresented: $showingAddCard) {
            CardEditorSheet(card: nil) { reloadCards() }
        }
        .sheet(item: $editingCard) { card in
            CardEditorSheet(card: card) { reloadCards() }
        }
        .sheet(isPresented: $showingStudySession, onDismiss: { reloadCards() }) {
            StudySessionView()
        }
        .alert("Delete Card?", isPresented: Binding(
            get: { cardToDelete != nil },
            set: { if !$0 { cardToDelete = nil } }
        )) {
            Button("Cancel", role: .cancel) { cardToDelete = nil }
            Button("Delete", role: .destructive) {
                if let card = cardToDelete {
                    try? DatabaseManager.shared.deleteAnkiCard(id: card.id)
                    reloadCards()
                }
                cardToDelete = nil
            }
        }
    }

    private var dueCount: Int {
        cards.filter(\.isDueForReview).count
    }

    private var accuracyString: String {
        let withReps = cards.filter { $0.repetitions > 0 }
        guard !withReps.isEmpty else { return "—" }
        let avgEF = withReps.reduce(0.0) { $0 + $1.easeFactor } / Double(withReps.count)
        return String(format: "%.0f%%", min(100, (avgEF / 2.5) * 100))
    }

    private var intervalDistribution: [(bucket: String, count: Int)] {
        let buckets: [(String, ClosedRange<Int>)] = [
            ("1d", 0...1), ("2-3d", 2...3), ("4-7d", 4...7),
            ("8-14d", 8...14), ("15-30d", 15...30), ("30d+", 31...10000)
        ]
        return buckets.map { (label, range) in
            let count = cards.filter { range.contains($0.interval) }.count
            return (bucket: label, count: count)
        }
    }

    private func reloadCards() {
        cards = (try? DatabaseManager.shared.fetchAllAnkiCards()) ?? []
    }
}

struct AnkiCardCell: View {
    let card: AnkiCard
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(card.front)
                .font(.subheadline.weight(.medium))
                .lineLimit(2)

            HStack {
                Text("Next: \(card.nextReviewDate, style: .date)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
                if card.isDueForReview {
                    Circle()
                        .fill(.orange)
                        .frame(width: 6, height: 6)
                }
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 8).fill(.background.opacity(0.5)))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(.quaternary))
        .contextMenu {
            Button("Edit") { onEdit() }
            Button("Delete", role: .destructive) { onDelete() }
        }
        .onTapGesture { onEdit() }
    }
}

struct CardEditorSheet: View {
    let card: AnkiCard?
    let onSave: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var front = ""
    @State private var back = ""

    var body: some View {
        VStack(spacing: 16) {
            Text(card == nil ? "New Card" : "Edit Card")
                .font(.headline)

            TextField("Front (Question)", text: $front, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(3...6)

            TextField("Back (Answer)", text: $back, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(3...6)

            HStack {
                Button("Cancel") { dismiss() }
                Spacer()
                Button("Save") { save() }
                    .buttonStyle(.borderedProminent)
                    .disabled(front.trimmingCharacters(in: .whitespaces).isEmpty ||
                              back.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 400)
        .onAppear {
            if let card {
                front = card.front
                back = card.back
            }
        }
    }

    private func save() {
        let db = DatabaseManager.shared
        if var existing = card {
            existing.front = front.trimmingCharacters(in: .whitespaces)
            existing.back = back.trimmingCharacters(in: .whitespaces)
            try? db.updateAnkiCard(existing)
        } else {
            let newCard = AnkiCard(
                front: front.trimmingCharacters(in: .whitespaces),
                back: back.trimmingCharacters(in: .whitespaces)
            )
            try? db.createAnkiCard(newCard)
        }
        onSave()
        dismiss()
    }
}

struct StudySessionView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var dueCards: [AnkiCard] = []
    @State private var currentIndex = 0
    @State private var showingAnswer = false
    @State private var userAnswer = ""

    var body: some View {
        VStack(spacing: 20) {
            if currentIndex < dueCards.count {
                let card = dueCards[currentIndex]

                Text("Card \(currentIndex + 1) of \(dueCards.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                // Front
                Text(card.front)
                    .font(.title3.weight(.medium))
                    .multilineTextAlignment(.center)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(RoundedRectangle(cornerRadius: 12).fill(.background.opacity(0.5)))

                if showingAnswer {
                    // Show answer
                    Text(verbatim: card.back)
                        .font(.body)
                        .multilineTextAlignment(.leading)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 12).fill(.green.opacity(0.1)))

                    HStack(spacing: 12) {
                        Button("Incorrect") { recordAnswer(correct: false) }
                            .buttonStyle(.bordered)
                            .tint(.red)
                        Button("Correct") { recordAnswer(correct: true) }
                            .buttonStyle(.borderedProminent)
                    }
                } else {
                    TextField("Your answer…", text: $userAnswer)
                        .textFieldStyle(.roundedBorder)

                    Button("Show Answer") {
                        showingAnswer = true
                    }
                    .buttonStyle(.bordered)
                }
            } else {
                Image(systemName: "checkmark.circle.fill")
                    .font(.largeTitle)
                    .foregroundStyle(.green)
                Text("All done!")
                    .font(.title3)
                Button("Close") { dismiss() }
            }
        }
        .padding(30)
        .frame(width: 450, height: 400)
        .background(.ultraThinMaterial)
        .overlay(alignment: .topLeading) {
            Button(action: { dismiss() }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .padding(10)
        }
        .onAppear {
            dueCards = (try? DatabaseManager.shared.fetchDueAnkiCards()) ?? []
        }
    }

    private func recordAnswer(correct: Bool) {
        var card = dueCards[currentIndex]
        card.review(quality: correct ? 4 : 1)
        try? DatabaseManager.shared.updateAnkiCard(card)
        dueCards[currentIndex] = card

        showingAnswer = false
        userAnswer = ""
        currentIndex += 1
    }
}
