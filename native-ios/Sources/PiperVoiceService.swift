import Foundation
import AVFoundation
import piper_player

actor PiperVoiceService {
    enum Voice: String, CaseIterable, Identifiable {
        case cadu, jeff
        var id: String { rawValue }
        var title: String { rawValue.capitalized + " — pt-BR medium" }
        var stem: String { "pt_BR-\(rawValue)-medium" }
        var baseURL: URL { URL(string: "https://huggingface.co/rhasspy/piper-voices/resolve/main/pt/pt_BR/\(rawValue)/medium/")! }
    }

    private var player: PiperPlayer?
    private var loadedVoice: Voice?

    func prepare(_ voice: Voice, progress: @escaping @Sendable (String) -> Void) async throws {
        if loadedVoice == voice, player != nil { return }
        progress("Preparando voz \(voice.title)…")
        let paths = try await ensureFiles(voice, progress: progress)
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .spokenAudio, options: [.allowBluetooth, .allowAirPlay])
        try session.setActive(true)
        player = try PiperPlayer(params: .init(modelPath: paths.model.path, configPath: paths.config.path))
        loadedVoice = voice
        progress("Voz neural pronta e offline.")
    }

    func speak(_ text: String) async throws {
        guard let player else { throw VoiceError.notPrepared }
        try await player.play(text: text)
    }

    func stop() async {
        await player?.stopAndCancel()
    }

    private func ensureFiles(_ voice: Voice, progress: @escaping @Sendable (String) -> Void) async throws -> (model: URL, config: URL) {
        let fm = FileManager.default
        let root = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("PiperVoices", isDirectory: true)
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        let model = root.appendingPathComponent("\(voice.stem).onnx")
        let config = root.appendingPathComponent("\(voice.stem).onnx.json")

        if !fm.fileExists(atPath: model.path) {
            progress("Baixando modelo pt-BR (~63 MB)…")
            try await download(voice.baseURL.appendingPathComponent("\(voice.stem).onnx"), to: model)
        }
        if !fm.fileExists(atPath: config.path) {
            progress("Baixando configuração da voz…")
            try await download(voice.baseURL.appendingPathComponent("\(voice.stem).onnx.json"), to: config)
        }
        return (model, config)
    }

    private func download(_ source: URL, to destination: URL) async throws {
        let (temp, response) = try await URLSession.shared.download(from: source)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw VoiceError.downloadFailed }
        try? FileManager.default.removeItem(at: destination)
        try FileManager.default.moveItem(at: temp, to: destination)
    }

    enum VoiceError: LocalizedError {
        case notPrepared, downloadFailed
        var errorDescription: String? {
            switch self {
            case .notPrepared: return "A voz ainda não foi preparada."
            case .downloadFailed: return "Não foi possível baixar a voz neural."
            }
        }
    }
}
