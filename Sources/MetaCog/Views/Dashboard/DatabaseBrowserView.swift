import SwiftUI
import GRDB

struct DatabaseBrowserView: View {
    @State private var tables: [String] = []
    @State private var selectedTable: String?
    @State private var rows: [[String: String]] = []
    @State private var columns: [String] = []
    @State private var customQuery = ""
    @State private var queryResult = ""

    var body: some View {
        HStack(spacing: 0) {
            List(tables, id: \.self, selection: $selectedTable) { table in
                Text(table)
                    .font(.system(.body, design: .monospaced))
            }
            .frame(width: 160)
            .onChange(of: selectedTable) { _, newValue in
                if let table = newValue { loadTable(table) }
            }

            Divider()

            VStack(spacing: 0) {
                // Query bar
                HStack {
                    TextField("SQL query…", text: $customQuery)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.caption, design: .monospaced))
                    Button("Run") { runQuery() }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                }
                .padding(8)

                if !queryResult.isEmpty {
                    ScrollView {
                        Text(queryResult)
                            .font(.system(.caption, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(8)
                            .textSelection(.enabled)
                    }
                    .frame(maxHeight: 150)
                    .background(.background.opacity(0.3))
                }

                Divider()

                // Table data as a simple grid
                if columns.isEmpty {
                    ContentUnavailableView("Select a table", systemImage: "tablecells")
                } else {
                    ScrollView([.horizontal, .vertical]) {
                        VStack(alignment: .leading, spacing: 0) {
                            // Header
                            HStack(spacing: 0) {
                                ForEach(columns, id: \.self) { col in
                                    Text(col)
                                        .font(.system(.caption, design: .monospaced, weight: .bold))
                                        .frame(width: 140, alignment: .leading)
                                        .padding(.horizontal, 4)
                                        .padding(.vertical, 4)
                                }
                            }
                            .background(Color.accentColor.opacity(0.1))

                            Divider()

                            // Rows
                            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                                HStack(spacing: 0) {
                                    ForEach(columns, id: \.self) { col in
                                        Text(row[col] ?? "NULL")
                                            .font(.system(.caption2, design: .monospaced))
                                            .frame(width: 140, alignment: .leading)
                                            .padding(.horizontal, 4)
                                            .padding(.vertical, 2)
                                            .lineLimit(1)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onAppear(perform: loadTables)
    }

    private func loadTables() {
        let db = DatabaseManager.shared
        tables = (try? db.dbQueue.read { db in
            try String.fetchAll(db, sql: "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name")
        }) ?? []
    }

    private func loadTable(_ name: String) {
        let db = DatabaseManager.shared
        do {
            try db.dbQueue.read { dbConn in
                let result = try Row.fetchAll(dbConn, sql: "SELECT * FROM \"\(name)\" LIMIT 500")
                if let first = result.first {
                    columns = Array(first.columnNames)
                } else {
                    columns = []
                }
                rows = result.map { row in
                    var dict: [String: String] = [:]
                    for col in row.columnNames {
                        dict[col] = row[col].map { "\($0)" } ?? "NULL"
                    }
                    return dict
                }
            }
        } catch {
            columns = []
            rows = []
        }
    }

    private func runQuery() {
        let db = DatabaseManager.shared
        do {
            let result = try db.dbQueue.read { dbConn in
                try Row.fetchAll(dbConn, sql: customQuery)
            }
            queryResult = result.map { "\($0)" }.joined(separator: "\n")
            if result.isEmpty { queryResult = "(no results)" }
        } catch {
            queryResult = "Error: \(error.localizedDescription)"
        }
    }
}
