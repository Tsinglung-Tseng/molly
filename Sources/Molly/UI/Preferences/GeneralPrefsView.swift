import SwiftUI

struct GeneralPrefsView: View {
    @State private var config: AppConfig = .init()
    @State private var configFileURL: URL? = nil

    var body: some View {
        Form {
            Section("Vault") {
                LabeledContent("Vault Path:") {
                    HStack {
                        Text(config.vaultPath.isEmpty ? "Not configured" : config.vaultPath)
                            .foregroundStyle(config.vaultPath.isEmpty ? .secondary : .primary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Spacer()
                        Button("Choose…") { chooseVaultPath() }
                    }
                }
                LabeledContent("Claude Binary:") {
                    HStack {
                        TextField("/path/to/claude", text: $config.claudeBin)
                            .textFieldStyle(.roundedBorder)
                            .onChange(of: config.claudeBin) { save() }
                        Button("Detect") { detectClaudeBin() }
                    }
                }
            }

            Section("LLM") {
                LabeledContent("API URL:") {
                    TextField("", text: $config.llm.apiURL)
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: config.llm.apiURL) { save() }
                }
                LabeledContent("API Key:") {
                    SecureField("", text: $config.llm.apiKey)
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: config.llm.apiKey) { save() }
                }
                LabeledContent("Model:") {
                    TextField("", text: $config.llm.model)
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: config.llm.model) { save() }
                }
            }

            Section("Config File") {
                LabeledContent("config.json:") {
                    HStack(alignment: .center) {
                        if let url = configFileURL {
                            Text(url.path)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                        Spacer()
                        Button("Open") {
                            Task {
                                guard let url = configFileURL else { return }
                                if !FileManager.default.fileExists(atPath: url.path) {
                                    try? await ConfigStore.shared.update { _ in }
                                }
                                NSWorkspace.shared.open(url)
                            }
                        }
                        .buttonStyle(.bordered)
                        Button("Reload") {
                            Task {
                                try? await ConfigStore.shared.reload()
                                config = await ConfigStore.shared.config
                            }
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task {
            config = await ConfigStore.shared.config
            configFileURL = await ConfigStore.shared.configFileURL
        }
    }

    private func chooseVaultPath() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "Select your Obsidian Vault folder"
        if panel.runModal() == .OK, let url = panel.url {
            config.vaultPath = url.path
            save()
        }
    }

    private func detectClaudeBin() {
        let p = Process()
        p.executableURL = URL(filePath: "/bin/zsh")
        p.arguments = ["-l", "-c", "which claude"]
        let pipe = Pipe()
        p.standardOutput = pipe
        try? p.run()
        p.waitUntilExit()
        let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !output.isEmpty {
            config.claudeBin = output
            save()
        }
    }

    private func save() {
        let vaultPath = config.vaultPath
        let claudeBin = config.claudeBin
        let llm = config.llm
        Task {
            try? await ConfigStore.shared.update { cfg in
                cfg.vaultPath = vaultPath
                cfg.claudeBin = claudeBin
                cfg.llm = llm
            }
        }
    }
}
