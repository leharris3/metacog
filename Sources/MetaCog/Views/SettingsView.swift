import SwiftUI

struct SettingsView: View {
    @AppStorage("basePenaltySeconds") private var basePenaltySeconds: Double = 15
    @AppStorage("dailyOverrideLimit") private var dailyOverrideLimit: Int = 3

    var body: some View {
        Form {
            Section("Intervention") {
                LabeledContent("Base Penalty Duration") {
                    HStack {
                        Slider(value: $basePenaltySeconds, in: 5...120, step: 5)
                            .frame(width: 160)
                        Text("\(Int(basePenaltySeconds))s")
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                            .frame(width: 36, alignment: .trailing)
                    }
                }
                Stepper("Daily Override Budget: \(dailyOverrideLimit)", value: $dailyOverrideLimit, in: 0...10)
            }
        }
        .formStyle(.grouped)
        .frame(width: 400, height: 160)
    }
}