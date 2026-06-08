import Foundation
import SwiftUI

enum DictationMode: String, CaseIterable {
    case pushToTalk = "Push to Talk"
    case toggle = "Toggle"
}

enum TranscriptionProvider: String, CaseIterable, Hashable {
    case local = "local"
    case groq = "groq"
    case foundry = "foundry"
    case mai = "mai"
}

enum AppStatus: Equatable {
    case idle
    case recording
    case transcribing
    case error(String)
}

enum GroqAPIStatus: Equatable {
    case unknown
    case checking
    case operational
    case error(String)
}

@Observable
@MainActor
final class AppState {
    // MARK: - State
    var status: AppStatus = .idle
    var isOnboardingComplete: Bool {
        didSet { UserDefaults.standard.set(isOnboardingComplete, forKey: "isOnboardingComplete") }
    }
    var showOnboarding = false

    // MARK: - Settings
    var dictationMode: DictationMode {
        didSet { UserDefaults.standard.set(dictationMode.rawValue, forKey: "dictationMode") }
    }
    var hotkeyKeyCode: UInt16 {
        didSet { UserDefaults.standard.set(Int(hotkeyKeyCode), forKey: "hotkeyKeyCode") }
    }
    var hotkeyModifiers: UInt64 {
        didSet { UserDefaults.standard.set(hotkeyModifiers, forKey: "hotkeyModifiers") }
    }
    var includePunctuation: Bool {
        didSet { UserDefaults.standard.set(includePunctuation, forKey: "includePunctuation") }
    }
    var muteSystemAudio: Bool {
        didSet { UserDefaults.standard.set(muteSystemAudio, forKey: "muteSystemAudio") }
    }
    var hideIdlePill: Bool {
        didSet {
            UserDefaults.standard.set(hideIdlePill, forKey: "hideIdlePill")
            if hideIdlePill { overlayPanel?.orderOut(nil) } else { startPersistentOverlay() }
        }
    }
    var customVocabulary: [String] {
        didSet { UserDefaults.standard.set(customVocabulary, forKey: "customVocabulary") }
    }
    var transcriptionProvider: TranscriptionProvider {
        didSet {
            UserDefaults.standard.set(transcriptionProvider.rawValue, forKey: "transcriptionProvider")
            if transcriptionProvider != .local {
                transcriptionService.unloadModel()
                isModelLoaded = false
            }
        }
    }
    var groqAPIKey: String {
        didSet { UserDefaults.standard.set(groqAPIKey, forKey: "groqAPIKey") }
    }
    var groqModel: String {
        didSet { UserDefaults.standard.set(groqModel, forKey: "groqModel") }
    }
    var foundryEndpoint: String {
        didSet { UserDefaults.standard.set(foundryEndpoint, forKey: "foundryEndpoint") }
    }
    var foundryAPIKey: String {
        didSet { UserDefaults.standard.set(foundryAPIKey, forKey: "foundryAPIKey") }
    }
    var foundryTranscriptionDeployment: String {
        didSet { UserDefaults.standard.set(foundryTranscriptionDeployment, forKey: "foundryTranscriptionDeployment") }
    }
    var foundryChatDeployment: String {
        didSet { UserDefaults.standard.set(foundryChatDeployment, forKey: "foundryChatDeployment") }
    }
    var maiEndpoint: String {
        didSet { UserDefaults.standard.set(maiEndpoint, forKey: "maiEndpoint") }
    }
    var maiAPIKey: String {
        didSet { UserDefaults.standard.set(maiAPIKey, forKey: "maiAPIKey") }
    }
    var maiModel: String {
        didSet { UserDefaults.standard.set(maiModel, forKey: "maiModel") }
    }
    var transcriptionLanguage: String {
        didSet { UserDefaults.standard.set(transcriptionLanguage, forKey: "transcriptionLanguage") }
    }
    var selectedMicUID: String {
        didSet {
            UserDefaults.standard.set(selectedMicUID, forKey: "selectedMicUID")
            microphoneManager.applySelection(uid: selectedMicUID)
        }
    }

    // MARK: - Prompts
    var whisperPrompt: String {
        didSet { UserDefaults.standard.set(whisperPrompt, forKey: "whisperPrompt") }
    }
    var llmSystemPrompt: String {
        didSet { UserDefaults.standard.set(llmSystemPrompt, forKey: "llmSystemPrompt") }
    }

    // MARK: - Groq
    var groqAPIStatus: GroqAPIStatus = .unknown
    var groqFetchedModels: [String] = []

    // MARK: - Foundry
    var foundryAPIStatus: GroqAPIStatus = .unknown
    var isRunningAzureSetup = false
    var azureSetupStatus: GroqAPIStatus = .unknown

    // MARK: - MAI
    var maiAPIStatus: GroqAPIStatus = .unknown

    // MARK: - Usage (cumulative, persisted)
    var usagePromptTokens: Int {
        didSet { UserDefaults.standard.set(usagePromptTokens, forKey: "usagePromptTokens") }
    }
    var usageCompletionTokens: Int {
        didSet { UserDefaults.standard.set(usageCompletionTokens, forKey: "usageCompletionTokens") }
    }
    var usageTotalTokens: Int {
        didSet { UserDefaults.standard.set(usageTotalTokens, forKey: "usageTotalTokens") }
    }
    var usageTotalTime: Double {
        didSet { UserDefaults.standard.set(usageTotalTime, forKey: "usageTotalTime") }
    }
    var usageRequestCount: Int {
        didSet { UserDefaults.standard.set(usageRequestCount, forKey: "usageRequestCount") }
    }

    // MARK: - AI Mode Settings
    var aiModeKeyCode: UInt16 {
        didSet { UserDefaults.standard.set(Int(aiModeKeyCode), forKey: "aiModeKeyCode") }
    }
    var aiModeModifiers: UInt64 {
        didSet { UserDefaults.standard.set(aiModeModifiers, forKey: "aiModeModifiers") }
    }
    var aiModel: String {
        didSet { UserDefaults.standard.set(aiModel, forKey: "aiModel") }
    }

    // MARK: - Services
    let modelManager = ModelManager()
    let transcriptionService = TranscriptionService()
    let hotkeyService = HotkeyService()
    let aiHotkeyService = HotkeyService()
    let historyManager = HistoryManager()
    let snippetManager = SnippetManager()
    let microphoneManager = MicrophoneManager()
    var isModelLoaded = false   // tracked by @Observable — TranscriptionService is not
    var isAIMode = false
    var selectedContext: String? = nil

    var isReady: Bool {
        switch transcriptionProvider {
        case .local: return isModelLoaded
        case .groq: return !groqAPIKey.isEmpty
        case .foundry: return !foundryEndpoint.isEmpty && !foundryAPIKey.isEmpty && !foundryTranscriptionDeployment.isEmpty
        case .mai: return !maiEndpoint.isEmpty && !maiAPIKey.isEmpty && !maiModel.isEmpty
        }
    }

    // MARK: - Overlay
    var overlayPanel: OverlayPanel?
    var pendingNavSelection: NavItem? = nil


    // MARK: - Private
    private var isKeyHeld = false
    private var accessibilityWasGranted = false

    var shortcutDisplayString: String {
        KeyCodeMapping.displayString(
            keyCode: hotkeyKeyCode,
            modifiers: CGEventFlags(rawValue: hotkeyModifiers)
        )
    }

    var aiShortcutDisplayString: String {
        KeyCodeMapping.displayString(
            keyCode: aiModeKeyCode,
            modifiers: CGEventFlags(rawValue: aiModeModifiers)
        )
    }

    init() {
        isOnboardingComplete = UserDefaults.standard.bool(forKey: "isOnboardingComplete")
        dictationMode = DictationMode(rawValue: UserDefaults.standard.string(forKey: "dictationMode") ?? "") ?? .pushToTalk
        hotkeyKeyCode = UInt16(UserDefaults.standard.integer(forKey: "hotkeyKeyCode"))
        hotkeyModifiers = UInt64(UserDefaults.standard.integer(forKey: "hotkeyModifiers"))
        if UserDefaults.standard.object(forKey: "includePunctuation") == nil {
            includePunctuation = true
        } else {
            includePunctuation = UserDefaults.standard.bool(forKey: "includePunctuation")
        }
        muteSystemAudio = UserDefaults.standard.bool(forKey: "muteSystemAudio")
        hideIdlePill = UserDefaults.standard.bool(forKey: "hideIdlePill")
        customVocabulary = UserDefaults.standard.stringArray(forKey: "customVocabulary") ?? []
        transcriptionProvider = TranscriptionProvider(rawValue: UserDefaults.standard.string(forKey: "transcriptionProvider") ?? "") ?? .local
        groqAPIKey = UserDefaults.standard.string(forKey: "groqAPIKey") ?? ""
        groqModel = UserDefaults.standard.string(forKey: "groqModel") ?? "whisper-large-v3-turbo"
        foundryEndpoint = UserDefaults.standard.string(forKey: "foundryEndpoint") ?? ""
        foundryAPIKey = UserDefaults.standard.string(forKey: "foundryAPIKey") ?? ""
        foundryTranscriptionDeployment = UserDefaults.standard.string(forKey: "foundryTranscriptionDeployment") ?? "whisper"
        foundryChatDeployment = UserDefaults.standard.string(forKey: "foundryChatDeployment") ?? ""
        maiEndpoint = UserDefaults.standard.string(forKey: "maiEndpoint") ?? ""
        maiAPIKey = UserDefaults.standard.string(forKey: "maiAPIKey") ?? ""
        maiModel = UserDefaults.standard.string(forKey: "maiModel") ?? "mai-transcribe-1.5"
        transcriptionLanguage = UserDefaults.standard.string(forKey: "transcriptionLanguage") ?? "auto"
        selectedMicUID = UserDefaults.standard.string(forKey: "selectedMicUID") ?? ""
        aiModeKeyCode = UInt16(UserDefaults.standard.integer(forKey: "aiModeKeyCode"))
        aiModeModifiers = UInt64(UserDefaults.standard.integer(forKey: "aiModeModifiers"))
        aiModel = UserDefaults.standard.string(forKey: "aiModel") ?? "openai/gpt-oss-20b"
        groqFetchedModels = UserDefaults.standard.stringArray(forKey: "groqFetchedModels") ?? []
        whisperPrompt = UserDefaults.standard.string(forKey: "whisperPrompt") ?? ""
        llmSystemPrompt = UserDefaults.standard.string(forKey: "llmSystemPrompt") ?? "You are a concise assistant inside a macOS voice dictation app. The user spoke their request and it was transcribed. Answer directly — no preamble, no filler, no sign-off. If the answer is a single word or number, just say it. Match the brevity of the question."
        usagePromptTokens = UserDefaults.standard.integer(forKey: "usagePromptTokens")
        usageCompletionTokens = UserDefaults.standard.integer(forKey: "usageCompletionTokens")
        usageTotalTokens = UserDefaults.standard.integer(forKey: "usageTotalTokens")
        usageTotalTime = UserDefaults.standard.double(forKey: "usageTotalTime")
        usageRequestCount = UserDefaults.standard.integer(forKey: "usageRequestCount")

        // Apply saved mic selection — didSet doesn't fire during init
        if !selectedMicUID.isEmpty {
            microphoneManager.applySelection(uid: selectedMicUID)
        }

        // Default shortcut: Fn (debug uses Right Shift to avoid conflicting with prod)
        if hotkeyKeyCode == 0 && hotkeyModifiers == 0 {
            #if DEBUG
            hotkeyKeyCode = 60 // kVK_RightShift
            hotkeyModifiers = CGEventFlags.maskShift.rawValue
            #else
            hotkeyKeyCode = 63 // kVK_Function
            hotkeyModifiers = CGEventFlags.maskSecondaryFn.rawValue
            #endif
        }

        // Default AI shortcut: Right Option (debug uses Right Control)
        if aiModeKeyCode == 0 && aiModeModifiers == 0 {
            #if DEBUG
            aiModeKeyCode = 62 // kVK_RightControl
            aiModeModifiers = CGEventFlags.maskControl.rawValue
            #else
            aiModeKeyCode = 61 // kVK_RightOption
            aiModeModifiers = CGEventFlags.maskAlternate.rawValue
            #endif
        }

        if !isOnboardingComplete {
            showOnboarding = true
        }

        accessibilityWasGranted = PermissionService.isAccessibilityGranted()

        Task {
            await loadSelectedModel()
            if !groqAPIKey.isEmpty { await verifyAndFetchGroqModels() }
            if isFoundryConfigured { await verifyFoundry() }
            if isMAIConfigured { await verifyMAI() }
            setupHotkey()
            await MainActor.run { startPersistentOverlay() }
        }

        startAccessibilityMonitor()
    }

    private func startAccessibilityMonitor() {
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            guard let self else { timer.invalidate(); return }
            let granted = PermissionService.isAccessibilityGranted()
            if granted && !self.accessibilityWasGranted {
                DispatchQueue.main.async {
                    self.hotkeyService.stop()
                    self.aiHotkeyService.stop()
                    self.setupHotkey()
                }
            }
            self.accessibilityWasGranted = granted
        }
    }

    func setupHotkey() {
        // Normal dictation hotkey
        hotkeyService.targetKeyCode = CGKeyCode(hotkeyKeyCode)
        hotkeyService.targetModifiers = CGEventFlags(rawValue: hotkeyModifiers)

        hotkeyService.onKeyDown = { [weak self] in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isAIMode = false
                switch self.dictationMode {
                case .pushToTalk:
                    if self.status == .idle {
                        self.isKeyHeld = true
                        Task { await self.startDictation() }
                    }
                case .toggle:
                    if self.status == .idle {
                        Task { await self.startDictation() }
                    } else if self.status == .recording {
                        Task { await self.stopDictationAndPaste() }
                    }
                }
            }
        }

        hotkeyService.onKeyUp = { [weak self] in
            DispatchQueue.main.async {
                guard let self = self else { return }
                if self.dictationMode == .pushToTalk && self.isKeyHeld && self.status == .recording {
                    self.isKeyHeld = false
                    Task { await self.stopDictationAndPaste() }
                }
            }
        }

        hotkeyService.start()

        // AI mode hotkey
        aiHotkeyService.targetKeyCode = CGKeyCode(aiModeKeyCode)
        aiHotkeyService.targetModifiers = CGEventFlags(rawValue: aiModeModifiers)

        aiHotkeyService.onKeyDown = { [weak self] in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isAIMode = true
                Task { @MainActor [weak self] in
                    guard let self = self else { return }
                    self.selectedContext = await PasteService.getSelectedText()
                    switch self.dictationMode {
                    case .pushToTalk:
                        if self.status == .idle {
                            self.isKeyHeld = true
                            await self.startDictation()
                        }
                    case .toggle:
                        if self.status == .idle {
                            await self.startDictation()
                        } else if self.status == .recording {
                            await self.stopDictationAndPaste()
                        }
                    }
                }
            }
        }

        aiHotkeyService.onKeyUp = { [weak self] in
            DispatchQueue.main.async {
                guard let self = self else { return }
                if self.dictationMode == .pushToTalk && self.isKeyHeld && self.status == .recording {
                    self.isKeyHeld = false
                    Task { await self.stopDictationAndPaste() }
                }
            }
        }

        aiHotkeyService.start()

        overlayPanel?.setShortcutLabel(shortcutDisplayString)
        setupPillPressAndHold()
    }

    func setupPillPressAndHold() {
        overlayPanel?.onMouseDown = { [weak self] in
            guard let self else { return }
            self.isAIMode = false
            if self.status == .idle {
                self.isKeyHeld = true
                Task { await self.startDictation() }
            }
        }
        overlayPanel?.onMouseUp = { [weak self] in
            guard let self else { return }
            if self.isKeyHeld && self.status == .recording {
                self.isKeyHeld = false
                Task { await self.stopDictationAndPaste() }
            }
        }
    }

    func startDictation() async {
        guard isReady else {
            status = .error(providerReadinessError)
            try? await Task.sleep(for: .seconds(2))
            status = .idle
            return
        }

        // Dismiss any visible answer card before starting a new session
        overlayPanel?.hideAnswer()

        do {
            status = .recording
            showOverlay()
            overlayPanel?.setAIMode(isAIMode)
            if !selectedMicUID.isEmpty { microphoneManager.applySelection(uid: selectedMicUID) }
            if muteSystemAudio { SystemAudioDucker.duck() }
            try await transcriptionService.startRecording()
            // Poll mic level and drive overlay visualization
            Task { [weak self] in
                while let self, self.status == .recording {
                    let level = await self.transcriptionService.audioLevel()
                    self.overlayPanel?.setAudioLevel(level)
                    try? await Task.sleep(for: .milliseconds(33))
                }
            }
        } catch {
            if muteSystemAudio { SystemAudioDucker.restore() }
            status = .error("Recording failed")
            overlayPanel?.updateStatus(status)
            try? await Task.sleep(for: .seconds(2))
            status = .idle
            hideOverlayIfIdle()
            overlayPanel?.setAIMode(false)
            isAIMode = false
        }
    }

    func stopDictationAndPaste() async {
        status = .transcribing
        updateOverlay()

        let prompt = customVocabulary.isEmpty ? nil : customVocabulary.joined(separator: " ")
        let lang = transcriptionLanguage == "auto" ? nil : transcriptionLanguage
        let transcribed: String?
        switch transcriptionProvider {
        case .local:
            transcribed = await transcriptionService.stopRecordingAndTranscribe(includePunctuation: includePunctuation, language: lang, initialPrompt: prompt)
        case .groq:
            transcribed = await transcriptionService.stopRecordingAndTranscribeWithGroq(
                apiKey: groqAPIKey,
                model: groqModel,
                includePunctuation: includePunctuation,
                language: lang,
                initialPrompt: prompt
            )
        case .foundry:
            var foundryTranscribed = await transcriptionService.stopRecordingAndTranscribeWithFoundry(
                endpoint: foundryEndpoint,
                apiKey: foundryAPIKey,
                deployment: foundryTranscriptionDeployment,
                includePunctuation: includePunctuation,
                language: lang,
                initialPrompt: prompt
            )
            if foundryTranscribed == nil && isMAIConfigured {
                foundryTranscribed = await transcriptionService.stopRecordingAndTranscribeWithMAI(
                    endpoint: maiEndpoint,
                    apiKey: maiAPIKey,
                    model: maiModel,
                    includePunctuation: includePunctuation,
                    language: lang,
                    phraseList: customVocabulary
                )
            }
            transcribed = foundryTranscribed
        case .mai:
            transcribed = await transcriptionService.stopRecordingAndTranscribeWithMAI(
                endpoint: maiEndpoint,
                apiKey: maiAPIKey,
                model: maiModel,
                includePunctuation: includePunctuation,
                language: lang,
                phraseList: customVocabulary
            )
        }
        if muteSystemAudio { SystemAudioDucker.restore() }

        let text: String?
        if isAIMode, let query = transcribed, !query.isEmpty {
            print("[wave] sending to AI: '\(query)'")
            var fullPrompt = llmSystemPrompt
            if !snippetManager.snippets.isEmpty {
                let snippetLines = snippetManager.snippets.map { "- \($0.name): \($0.value)" }.joined(separator: "\n")
                fullPrompt += "\n\nUser snippets (use when relevant):\n\(snippetLines)"
            }
            var userMessage = query
            if let context = selectedContext {
                userMessage = "Selected text:\n\"\"\"\n\(context)\n\"\"\"\n\nInstruction: \(query)"
            }
            if let result = await sendCurrentProviderAI(text: userMessage, systemPrompt: fullPrompt) {
                usagePromptTokens += result.promptTokens
                usageCompletionTokens += result.completionTokens
                usageTotalTokens += result.totalTokens
                usageTotalTime += result.totalTime
                usageRequestCount += 1
                text = result.text
            } else {
                text = transcribed
            }
        } else {
            text = transcribed
        }

        status = .idle
        overlayPanel?.setAIMode(false)
        let wasAIMode = isAIMode
        let hadSelection = selectedContext != nil
        isAIMode = false
        selectedContext = nil
        hideOverlayIfIdle()

        if let text = text, !text.isEmpty {
            historyManager.add(text)

            // Route:
            // - Regular dictation → always paste
            // - AI mode: paste only if there's an editable field to paste into.
            //   Otherwise (reading webpage, PDF, etc.), show the answer card.
            //   Selected text is just context for the LLM, not a routing signal.
            let shouldShowCard = wasAIMode && !PasteService.hasEditableFocus()

            if shouldShowCard {
                print("[wave] showing answer card: '\(text)'")
                overlayPanel?.showAnswer(
                    text,
                    onCopy: { [weak self] in
                        self?.copyAnswerToClipboard(text)
                    },
                    onClose: { [weak self] in
                        self?.overlayPanel?.hideAnswer()
                    }
                )
            } else {
                print("[wave] pasting: '\(text)' (hadSelection=\(hadSelection))")
                try? await Task.sleep(for: .milliseconds(100))
                PasteService.paste(text: text)
            }
        } else {
            print("[wave] nothing to paste")
        }

        status = .idle
    }

    private func copyAnswerToClipboard(_ text: String) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(text, forType: .string)
    }

    func verifyAndFetchGroqModels() async {
        guard !groqAPIKey.isEmpty else { groqAPIStatus = .unknown; return }
        groqAPIStatus = .checking

        let url = URL(string: "https://api.groq.com/openai/v1/models")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(groqAPIKey)", forHTTPHeaderField: "Authorization")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                groqAPIStatus = .error("Invalid API key")
                return
            }
            struct GroqModelEntry: Decodable {
                let id: String
                let active: Bool
                enum CodingKeys: String, CodingKey { case id, active }
            }
            struct GroqModelList: Decodable { let data: [GroqModelEntry] }
            let list = try JSONDecoder().decode(GroqModelList.self, from: data)
            let chatModels = list.data
                .filter { $0.active && !$0.id.localizedCaseInsensitiveContains("whisper") && !$0.id.localizedCaseInsensitiveContains("distil") }
                .map { $0.id }
                .sorted()
            groqFetchedModels = chatModels
            UserDefaults.standard.set(chatModels, forKey: "groqFetchedModels")
            groqAPIStatus = .operational
        } catch {
            groqAPIStatus = .error("Connection failed")
        }
    }

    func verifyFoundry() async {
        guard isFoundryEndpointConfigured else { foundryAPIStatus = .unknown; return }
        foundryAPIStatus = .checking

        guard let url = TranscriptionService.foundryOpenAIV1URL(endpoint: foundryEndpoint, path: "models") else {
            foundryAPIStatus = .error("Invalid endpoint")
            return
        }
        var request = URLRequest(url: url)
        request.setValue(foundryAPIKey, forHTTPHeaderField: "api-key")

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                foundryAPIStatus = .error("Invalid settings")
                return
            }
            foundryAPIStatus = .operational
        } catch {
            foundryAPIStatus = .error("Connection failed")
        }
    }

    var isFoundryConfigured: Bool {
        !foundryEndpoint.isEmpty && !foundryAPIKey.isEmpty && !foundryTranscriptionDeployment.isEmpty
    }

    var isFoundryEndpointConfigured: Bool {
        !foundryEndpoint.isEmpty && !foundryAPIKey.isEmpty
    }

    func runFoundryDeploymentScript() {
        guard !isRunningAzureSetup else { return }

        let scriptURL = Self.foundryDeploymentScriptURL
        let credentialsURL = Self.azureCredentialsURL

        guard FileManager.default.fileExists(atPath: scriptURL.path) else {
            azureSetupStatus = .error("Script not found")
            return
        }

        isRunningAzureSetup = true
        azureSetupStatus = .checking

        Task {
            let result = await Self.runScript(scriptURL: scriptURL, credentialsURL: credentialsURL)
            guard result.exitCode == 0 else {
                isRunningAzureSetup = false
                azureSetupStatus = .error(Self.displayError(from: result.output))
                return
            }

            do {
                try importAzureCredentials(from: credentialsURL)
                azureSetupStatus = .operational
                isRunningAzureSetup = false
                await verifyFoundry()
                await verifyMAI()
            } catch {
                isRunningAzureSetup = false
                azureSetupStatus = .error("Credentials import failed")
            }
        }
    }

    private func importAzureCredentials(from url: URL) throws {
        let data = try Data(contentsOf: url)
        let credentials = try JSONDecoder().decode(AzureCredentials.self, from: data)

        guard !credentials.foundryEndpoint.isEmpty,
              !credentials.foundryAPIKey.isEmpty,
              !credentials.foundryChatDeployment.isEmpty,
              !credentials.maiEndpoint.isEmpty,
              !credentials.maiAPIKey.isEmpty else {
            throw AzureSetupError.missingCredentials
        }

        foundryEndpoint = credentials.foundryEndpoint
        foundryAPIKey = credentials.foundryAPIKey
        foundryTranscriptionDeployment = credentials.foundryTranscriptionDeployment
        foundryChatDeployment = credentials.foundryChatDeployment
        maiEndpoint = credentials.maiEndpoint
        maiAPIKey = credentials.maiAPIKey
        maiModel = credentials.maiModel
        transcriptionProvider = .foundry
    }

    private struct AzureCredentials: Decodable {
        let foundryEndpoint: String
        let foundryAPIKey: String
        let foundryTranscriptionDeployment: String
        let foundryChatDeployment: String
        let maiEndpoint: String
        let maiAPIKey: String
        let maiModel: String
    }

    private enum AzureSetupError: Error {
        case missingCredentials
    }

    private static var foundryDeploymentScriptURL: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("infra/deploy-foundry-wave-app.sh")
    }

    private static var azureCredentialsURL: URL {
        FileManager.default
            .homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/Wave/azure-credentials.json")
    }

    private nonisolated static func runScript(scriptURL: URL, credentialsURL: URL) async -> (exitCode: Int32, output: String) {
        await Task.detached {
            let process = Process()
            let pipe = Pipe()
            var environment = ProcessInfo.processInfo.environment
            environment["WAVE_AZURE_CREDENTIALS_FILE"] = credentialsURL.path

            process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            process.arguments = ["bash", scriptURL.path, "--non-interactive"]
            process.currentDirectoryURL = scriptURL.deletingLastPathComponent().deletingLastPathComponent()
            process.environment = environment
            process.standardOutput = pipe
            process.standardError = pipe

            do {
                try process.run()
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                process.waitUntilExit()
                return (process.terminationStatus, String(data: data, encoding: .utf8) ?? "")
            } catch {
                return (1, error.localizedDescription)
            }
        }.value
    }

    private nonisolated static func displayError(from output: String) -> String {
        output
            .split(whereSeparator: \.isNewline)
            .last
            .map(String.init) ?? "Azure setup failed"
    }

    func verifyMAI() async {
        guard isMAIConfigured else { maiAPIStatus = .unknown; return }
        maiAPIStatus = .checking

        guard let url = TranscriptionService.maiTranscriptionURL(endpoint: maiEndpoint) else {
            maiAPIStatus = .error("Invalid endpoint")
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(maiAPIKey, forHTTPHeaderField: "Ocp-Apim-Subscription-Key")

        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        let definition: [String: Any] = [
            "enhancedMode": [
                "enabled": true,
                "model": maiModel
            ]
        ]
        guard let definitionData = try? JSONSerialization.data(withJSONObject: definition),
              let definitionString = String(data: definitionData, encoding: .utf8) else {
            maiAPIStatus = .error("Invalid settings")
            return
        }

        var body = Data()
        func append(_ string: String) { body.append(string.data(using: .utf8)!) }
        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"definition\"\r\n\r\n")
        append(definitionString)
        append("\r\n")
        append("--\(boundary)--\r\n")
        request.httpBody = body

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                maiAPIStatus = .error("Connection failed")
                return
            }
            if (200..<300).contains(http.statusCode) || String(data: data, encoding: .utf8)?.localizedCaseInsensitiveContains("Audio data must be provided") == true {
                maiAPIStatus = .operational
            } else if http.statusCode == 401 || http.statusCode == 403 {
                maiAPIStatus = .error("Invalid API key")
            } else {
                maiAPIStatus = .error("Invalid settings")
            }
        } catch {
            maiAPIStatus = .error("Connection failed")
        }
    }

    var isMAIConfigured: Bool {
        !maiEndpoint.isEmpty && !maiAPIKey.isEmpty && !maiModel.isEmpty
    }

    func loadSelectedModel() async {
        guard let path = modelManager.selectedModelPath else { return }
        do {
            try await transcriptionService.loadModel(path: path)
            isModelLoaded = true
        } catch {
            print("Failed to load model: \(error)")
            isModelLoaded = false
            status = .error("Failed to load model")
            try? await Task.sleep(for: .seconds(2))
            status = .idle
        }
    }

    private var providerReadinessError: String {
        switch transcriptionProvider {
        case .local: return "No model loaded"
        case .groq: return "Groq API key required"
        case .foundry: return "Foundry settings required"
        case .mai: return "MAI settings required"
        }
    }

    private func sendCurrentProviderAI(text: String, systemPrompt: String) async -> TranscriptionService.AIResult? {
        switch transcriptionProvider {
        case .local:
            return nil
        case .groq:
            guard !groqAPIKey.isEmpty else { return nil }
            return await transcriptionService.sendToAI(text: text, apiKey: groqAPIKey, model: aiModel, systemPrompt: systemPrompt)
        case .foundry:
            guard !foundryEndpoint.isEmpty, !foundryAPIKey.isEmpty, !foundryChatDeployment.isEmpty else { return nil }
            return await transcriptionService.sendToAIWithFoundry(
                text: text,
                endpoint: foundryEndpoint,
                apiKey: foundryAPIKey,
                deployment: foundryChatDeployment,
                systemPrompt: systemPrompt
            )
        case .mai:
            return nil
        }
    }

    // MARK: - Overlay

    func showOverlay() {
        if overlayPanel == nil {
            overlayPanel = OverlayPanel()
            overlayPanel?.setShortcutLabel(shortcutDisplayString)
            setupPillPressAndHold()
        }
        overlayPanel?.updateStatus(status)
    }

    func hideOverlayIfIdle() {
        if hideIdlePill {
            overlayPanel?.orderOut(nil)
        } else {
            overlayPanel?.updateStatus(.idle)
        }
    }

    func updateOverlay() {
        overlayPanel?.updateStatus(status)
    }

    func hideOverlay() {
        status = .idle
        hideOverlayIfIdle()
    }

    func startPersistentOverlay() {
        guard !hideIdlePill else { return }
        if overlayPanel == nil {
            overlayPanel = OverlayPanel()
            overlayPanel?.setShortcutLabel(shortcutDisplayString)
            setupPillPressAndHold()
        }
        overlayPanel?.updateStatus(.idle)
    }
}
