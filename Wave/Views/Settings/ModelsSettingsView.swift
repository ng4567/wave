import SwiftUI

struct ModelsSettingsView: View {
    @Environment(AppState.self) private var appState
    @State private var showProviderPicker = false
    @State private var showLLMPicker = false
    @State private var isEditingKey = false
    @State private var isEditingFoundryKey = false
    @State private var isEditingMAIKey = false

    var body: some View {
        @Bindable var state = appState

        VStack(alignment: .leading, spacing: 20) {
                section("Models") {
                    modelRow(
                        icon: "waveform",
                        label: "Audio",
                        value: audioModelLabel,
                        action: { showProviderPicker = true }
                    )
                    modelRow(
                        icon: "brain",
                        label: "LLM",
                        value: aiModelLabel,
                        action: (appState.transcriptionProvider == .groq && !appState.groqAPIKey.isEmpty) ? { showLLMPicker = true } : nil
                    )
                }

                section("Provider") {
                    Picker("", selection: Binding(
                        get: { appState.transcriptionProvider },
                        set: { appState.transcriptionProvider = $0 }
                    )) {
                        Text("Local").tag(TranscriptionProvider.local)
                        Text("Groq").tag(TranscriptionProvider.groq)
                        Text("Foundry").tag(TranscriptionProvider.foundry)
                        Text("MAI").tag(TranscriptionProvider.mai)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }

                if appState.transcriptionProvider == .groq {
                    section("Groq") {
                        if !appState.groqAPIKey.isEmpty && !isEditingKey {
                            HStack(spacing: 6) {
                                Text(maskedAPIKey)
                                    .font(.system(size: 12, design: .monospaced))
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Button("Edit") { isEditingKey = true }
                                    .font(.system(size: 12, weight: .medium, design: .rounded))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))
                                    .buttonStyle(.plain)
                            }
                        } else {
                            HStack(spacing: 6) {
                                TextField("API Key (gsk_...)", text: Binding(
                                    get: { appState.groqAPIKey },
                                    set: { appState.groqAPIKey = $0 }
                                ))
                                .textFieldStyle(.roundedBorder)
                                .font(.system(size: 12, design: .monospaced))
                                Button("Save") {
                                    Task {
                                        await appState.verifyAndFetchGroqModels()
                                        if appState.groqAPIStatus == .operational {
                                            isEditingKey = false
                                        }
                                    }
                                }
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Color.brand.opacity(0.15), in: RoundedRectangle(cornerRadius: 7))
                                .foregroundStyle(Color.brand)
                                .buttonStyle(.plain)
                                .disabled(appState.groqAPIKey.isEmpty || appState.groqAPIStatus == .checking)
                            }
                        }

                        groqStatusView
                    }
                }

                if appState.transcriptionProvider == .foundry {
                    section("Foundry") {
                        fieldRow("Endpoint", placeholder: "https://resource.openai.azure.com", text: Binding(
                            get: { appState.foundryEndpoint },
                            set: { appState.foundryEndpoint = $0 }
                        ))
                        fieldRow("Transcription", placeholder: "whisper deployment", text: Binding(
                            get: { appState.foundryTranscriptionDeployment },
                            set: { appState.foundryTranscriptionDeployment = $0 }
                        ))
                        fieldRow("Chat", placeholder: "optional AI Mode deployment", text: Binding(
                            get: { appState.foundryChatDeployment },
                            set: { appState.foundryChatDeployment = $0 }
                        ))

                        if !appState.foundryAPIKey.isEmpty && !isEditingFoundryKey {
                            HStack(spacing: 6) {
                                Text(maskedFoundryAPIKey)
                                    .font(.system(size: 12, design: .monospaced))
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Button("Edit") { isEditingFoundryKey = true }
                                    .font(.system(size: 12, weight: .medium, design: .rounded))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))
                                    .buttonStyle(.plain)
                            }
                        } else {
                            HStack(spacing: 6) {
                                SecureField("API Key", text: Binding(
                                    get: { appState.foundryAPIKey },
                                    set: { appState.foundryAPIKey = $0 }
                                ))
                                .textFieldStyle(.roundedBorder)
                                .font(.system(size: 12, design: .monospaced))
                                Button("Save") {
                                    Task {
                                        await appState.verifyFoundry()
                                        if appState.foundryAPIStatus == .operational {
                                            isEditingFoundryKey = false
                                        }
                                    }
                                }
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Color.brand.opacity(0.15), in: RoundedRectangle(cornerRadius: 7))
                                .foregroundStyle(Color.brand)
                                .buttonStyle(.plain)
                                .disabled(!appState.isFoundryConfigured || appState.foundryAPIStatus == .checking)
                            }
                        }

                        foundryStatusView
                    }
                }

                if appState.transcriptionProvider == .mai {
                    section("MAI") {
                        fieldRow("Endpoint", placeholder: "https://resource.cognitiveservices.azure.com", text: Binding(
                            get: { appState.maiEndpoint },
                            set: { appState.maiEndpoint = $0 }
                        ))
                        fieldRow("Model", placeholder: "mai-transcribe-1.5", text: Binding(
                            get: { appState.maiModel },
                            set: { appState.maiModel = $0 }
                        ))

                        if !appState.maiAPIKey.isEmpty && !isEditingMAIKey {
                            HStack(spacing: 6) {
                                Text(maskedMAIAPIKey)
                                    .font(.system(size: 12, design: .monospaced))
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Button("Edit") { isEditingMAIKey = true }
                                    .font(.system(size: 12, weight: .medium, design: .rounded))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))
                                    .buttonStyle(.plain)
                            }
                        } else {
                            HStack(spacing: 6) {
                                SecureField("API Key", text: Binding(
                                    get: { appState.maiAPIKey },
                                    set: { appState.maiAPIKey = $0 }
                                ))
                                .textFieldStyle(.roundedBorder)
                                .font(.system(size: 12, design: .monospaced))
                                Button("Save") {
                                    Task {
                                        await appState.verifyMAI()
                                        if appState.maiAPIStatus == .operational {
                                            isEditingMAIKey = false
                                        }
                                    }
                                }
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Color.brand.opacity(0.15), in: RoundedRectangle(cornerRadius: 7))
                                .foregroundStyle(Color.brand)
                                .buttonStyle(.plain)
                                .disabled(!appState.isMAIConfigured || appState.maiAPIStatus == .checking)
                            }
                        }

                        maiStatusView
                    }
                }

                section("LLM System Prompt") {
                    TextEditor(text: $state.llmSystemPrompt)
                        .font(.system(size: 12))
                        .frame(minHeight: 80, maxHeight: 120)
                        .scrollContentBackground(.hidden)
                        .padding(8)
                        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
                    Text("Instructions for the AI when using AI Mode shortcut.")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .sheet(isPresented: $showProviderPicker) {
            ProviderPickerView()
                .environment(appState)
                .frame(width: 420)
        }
        .sheet(isPresented: $showLLMPicker) {
            LLMPickerView()
                .environment(appState)
                .frame(width: 520)
        }
    }

    @ViewBuilder
    private var groqStatusView: some View {
        switch appState.groqAPIStatus {
        case .unknown:
            EmptyView()
        case .checking:
            HStack(spacing: 5) {
                ProgressView().scaleEffect(0.6).frame(width: 8, height: 8)
                Text("Verifying...")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        case .operational:
            HStack(spacing: 5) {
                Circle().fill(.green).frame(width: 6, height: 6)
                Text("Operational")
                    .font(.system(size: 11))
                    .foregroundStyle(.green)
            }
        case .error(let msg):
            HStack(spacing: 5) {
                Circle().fill(.red).frame(width: 6, height: 6)
                Text(msg)
                    .font(.system(size: 11))
                    .foregroundStyle(.red)
            }
        }
    }

    @ViewBuilder
    private var foundryStatusView: some View {
        switch appState.foundryAPIStatus {
        case .unknown:
            EmptyView()
        case .checking:
            HStack(spacing: 5) {
                ProgressView().scaleEffect(0.6).frame(width: 8, height: 8)
                Text("Verifying...")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        case .operational:
            HStack(spacing: 5) {
                Circle().fill(.green).frame(width: 6, height: 6)
                Text("Operational")
                    .font(.system(size: 11))
                    .foregroundStyle(.green)
            }
        case .error(let msg):
            HStack(spacing: 5) {
                Circle().fill(.red).frame(width: 6, height: 6)
                Text(msg)
                    .font(.system(size: 11))
                    .foregroundStyle(.red)
            }
        }
    }

    @ViewBuilder
    private var maiStatusView: some View {
        switch appState.maiAPIStatus {
        case .unknown:
            EmptyView()
        case .checking:
            HStack(spacing: 5) {
                ProgressView().scaleEffect(0.6).frame(width: 8, height: 8)
                Text("Verifying...")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        case .operational:
            HStack(spacing: 5) {
                Circle().fill(.green).frame(width: 6, height: 6)
                Text("Operational")
                    .font(.system(size: 11))
                    .foregroundStyle(.green)
            }
        case .error(let msg):
            HStack(spacing: 5) {
                Circle().fill(.red).frame(width: 6, height: 6)
                Text(msg)
                    .font(.system(size: 11))
                    .foregroundStyle(.red)
            }
        }
    }

    private var maskedAPIKey: String {
        let key = appState.groqAPIKey
        guard key.count > 10 else { return key }
        let prefix = String(key.prefix(6))
        let suffix = String(key.suffix(4))
        return "\(prefix)...\(suffix)"
    }

    private var maskedFoundryAPIKey: String {
        let key = appState.foundryAPIKey
        guard key.count > 10 else { return key }
        let prefix = String(key.prefix(6))
        let suffix = String(key.suffix(4))
        return "\(prefix)...\(suffix)"
    }

    private var maskedMAIAPIKey: String {
        let key = appState.maiAPIKey
        guard key.count > 10 else { return key }
        let prefix = String(key.prefix(6))
        let suffix = String(key.suffix(4))
        return "\(prefix)...\(suffix)"
    }

    private var audioModelLabel: String {
        switch appState.transcriptionProvider {
        case .local:
            if let path = appState.modelManager.selectedModelPath {
                return "Local \u{00B7} \(URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent)"
            }
            return "No model selected"
        case .groq:
            return "Groq \u{00B7} \(appState.groqModel)"
        case .foundry:
            return "Foundry \u{00B7} \(appState.foundryTranscriptionDeployment)"
        case .mai:
            return "MAI \u{00B7} \(appState.maiModel)"
        }
    }

    private var aiModelLabel: String {
        if appState.transcriptionProvider == .foundry {
            return appState.foundryChatDeployment.isEmpty ? "No deployment selected" : appState.foundryChatDeployment
        }
        return llmModels.first(where: { $0.id == appState.aiModel })?.name ?? appState.aiModel
    }

    @ViewBuilder
    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            content()
        }
    }

    @ViewBuilder
    private func modelRow(icon: String, label: String, value: String, action: (() -> Void)?) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .frame(width: 16)
            Text(label)
                .font(.system(size: 13, weight: .medium))
            Spacer()
            Text(value)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .lineLimit(1)
            if let action {
                Button("Change\u{2026}") { action() }
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))
                    .buttonStyle(.plain)
            }
        }
        .padding(10)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
        .opacity(action == nil ? 0.5 : 1)
    }

    @ViewBuilder
    private func fieldRow(_ label: String, placeholder: String, text: Binding<String>) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.system(size: 13, weight: .medium))
                .frame(width: 86, alignment: .leading)
            TextField(placeholder, text: text)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 12, design: .monospaced))
        }
    }
}
