import SwiftUI

struct LogView: View {
    @ObservedObject private var logger = MollyLogger.shared
    @State private var selectedSource: String?

    private var filteredEntries: [LogEntry] {
        guard let source = selectedSource else { return logger.entries }
        return logger.entries.filter { $0.source == source }
    }

    private var allText: String {
        filteredEntries.map(\.formatted).joined(separator: "\n")
    }

    var body: some View {
        VStack(spacing: 0) {
            // Filter bar

            HStack(spacing: 8) {
                Picker("Source", selection: $selectedSource) {
                    Text("All").tag(String?.none)
                    ForEach(logger.sources, id: \.self) { source in
                        Text(source).tag(Optional(source))
                    }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: 200)

                Spacer()

                Text("\(filteredEntries.count) lines")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)

            Divider()

            // Log content
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 2) {
                        ForEach(filteredEntries) { entry in
                            HStack(alignment: .top, spacing: 6) {
                                Text(entry.timestamp)
                                    .foregroundStyle(.tertiary)
                                Text(entry.source)
                                    .foregroundStyle(.blue)
                                    .fontWeight(.medium)
                                Text(entry.message)
                                    .foregroundStyle(.secondary)
                            }
                            .font(.system(.caption, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                        }
                        Color.clear.frame(height: 1).id("bottom")
                    }
                    .padding(8)
                }
                .onChange(of: logger.entries.count) {
                    proxy.scrollTo("bottom")
                }
            }

            Divider()

            // Toolbar
            HStack(spacing: 12) {
                Button("Clear") { logger.clear() }
                    .buttonStyle(.borderless)
                    .font(.caption)

                Button("Copy") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(allText, forType: .string)
                }
                .buttonStyle(.borderless)
                .font(.caption)
                .disabled(filteredEntries.isEmpty)

                Spacer()
            }
            .padding(8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
