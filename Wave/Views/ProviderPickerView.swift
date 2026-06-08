import SwiftUI
import UniformTypeIdentifiers

struct ProviderPickerView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Audio Model")
                    .font(.title3.bold())
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                        .font(.system(size: 18))
                }
                .buttonStyle(.plain)
            }

            Divider()

            switch appState.transcriptionProvider {
            case .local:
                localContent
            case .groq:
                groqContent
            case .foundry:
                foundryContent
            case .mai:
                maiContent
            }
        }
        .padding()
    }

    // MARK: - Local

    @ViewBuilder
    private var localContent: some View {
        ScrollView {
            VStack(spacing: 8) {
                ForEach(WhisperModel.available) { model in
                    modelRow(model)
                }
            }
        }
        .frame(maxHeight: 260)

        HStack {
            Text("Or locate a model file:")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
            Spacer()
            Button("Choose File...") {
                let panel = NSOpenPanel()
                panel.allowedContentTypes = [.init(filenameExtension: "bin")!]
                panel.canChooseDirectories = false
                panel.allowsMultipleSelection = false
                if panel.runModal() == .OK, let url = panel.url {
                    appState.modelManager.selectModelAtPath(url.path)
                    Task { await appState.loadSelectedModel() }
                }
            }
            .font(.system(size: 13, weight: .medium, design: .rounded))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
            .buttonStyle(.plain)
        }
    }

    // MARK: - Groq

    @ViewBuilder
    private var groqContent: some View {
        VStack(alignment: .leading, spacing: 6) {
            Picker("", selection: Binding(
                get: { appState.groqModel },
                set: { appState.groqModel = $0 }
            )) {
                Text("whisper-large-v3-turbo  ·  faster  ·  $0.04/hr").tag("whisper-large-v3-turbo")
                Text("whisper-large-v3  ·  most accurate  ·  $0.111/hr").tag("whisper-large-v3")
            }
            .pickerStyle(.radioGroup)
            .labelsHidden()
        }
        .padding(.bottom, 8)
    }

    // MARK: - Foundry

    @ViewBuilder
    private var foundryContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Using deployment")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            Text(appState.foundryTranscriptionDeployment.isEmpty ? "No transcription deployment selected" : appState.foundryTranscriptionDeployment)
                .font(.system(size: 13, weight: .medium))
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
            Text("Change the Foundry deployment name in Models settings.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
        .padding(.bottom, 8)
    }

    // MARK: - MAI

    @ViewBuilder
    private var maiContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Using model")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            Text(appState.maiModel.isEmpty ? "No MAI model selected" : appState.maiModel)
                .font(.system(size: 13, weight: .medium))
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
        }
        .padding(.bottom, 8)
    }

    // MARK: - Local model row

    @ViewBuilder
    private func modelRow(_ model: WhisperModel) -> some View {
        let isDownloaded = appState.modelManager.isDownloaded(model)
        let isSelected = appState.modelManager.selectedModelPath == appState.modelManager.fileURL(for: model).path
        let isDownloading = appState.modelManager.downloadingModelId == model.id.uuidString

        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(model.name)
                        .font(.system(size: 13, weight: .medium))
                    Text(model.size)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                Text(model.type)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if isSelected {
                HStack(spacing: 8) {
                    Label("Active", systemImage: "checkmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.green)
                    Button(action: {
                        appState.modelManager.deleteModel(model)
                        appState.transcriptionService.unloadModel()
                        appState.isModelLoaded = false
                    }) {
                        Image(systemName: "trash")
                            .foregroundStyle(.red.opacity(0.8))
                            .font(.system(size: 12))
                    }
                    .buttonStyle(.plain)
                }
            } else if isDownloaded {
                HStack(spacing: 6) {
                    Button("Use") {
                        appState.modelManager.selectModel(model)
                        Task { await appState.loadSelectedModel() }
                    }
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
                    .buttonStyle(.plain)
                    Button(action: { appState.modelManager.deleteModel(model) }) {
                        Image(systemName: "trash")
                            .foregroundStyle(.red.opacity(0.8))
                            .font(.system(size: 12))
                    }
                    .buttonStyle(.plain)
                }
            } else if isDownloading {
                let progress = appState.modelManager.downloadProgress[model.id.uuidString] ?? 0
                HStack(spacing: 8) {
                    ProgressView(value: progress)
                        .frame(width: 60)
                    Text("\(Int(progress * 100))%")
                        .font(.system(size: 11).monospacedDigit())
                    Button(action: { appState.modelManager.cancelDownload() }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            } else {
                Button("Download") {
                    appState.modelManager.download(model)
                }
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
    }
}
