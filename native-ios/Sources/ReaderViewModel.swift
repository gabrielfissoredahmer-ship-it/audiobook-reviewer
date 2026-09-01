import Foundation
import SwiftUI
import UniformTypeIdentifiers

@MainActor
final class ReaderViewModel: ObservableObject {
    @Published var book: BookDocument?
    @Published var chapterIndex = 0
    @Published var sentenceIndex = 0
    @Published var selectedVoice: PiperVoiceService.Voice = .cadu
    @Published var status = "Abra um livro para começar."
    @Published var isPlaying = false
    @Published var isPreparingVoice = false
    @Published var showImporter = false

    private let voice = PiperVoiceService()
    private var playTask: Task<Void, Never>?

    var chapter: BookChapter? { book?.chapters[safe: chapterIndex] }
    var currentSentence: String { chapter?.sentences[safe: sentenceIndex] ?? "" }
    var progress: Double {
        guard let book else { return 0 }
        let total = book.chapters.reduce(0) { $0 + $1.sentences.count }
        let before = book.chapters.prefix(chapterIndex).reduce(0) { $0 + $1.sentences.count }
        return total == 0 ? 0 : Double(before + sentenceIndex) / Double(total)
    }

    func importFile(_ url: URL) {
        Task {
            let access = url.startAccessingSecurityScopedResource()
            defer { if access { url.stopAccessingSecurityScopedResource() } }
            do {
                status = "Lendo manuscrito…"
                let text = try DocumentImporter.read(url: url)
                book = BookParser.makeBook(name: url.deletingPathExtension().lastPathComponent, text: text)
                chapterIndex = 0
                sentenceIndex = 0
                restoreProgress()
                status = "Livro carregado."
            } catch {
                status = error.localizedDescription
            }
        }
    }

    func prepareVoice() {
        Task {
            isPreparingVoice = true
            defer { isPreparingVoice = false }
            do {
                try await voice.prepare(selectedVoice) { [weak self] text in
                    Task { @MainActor in self?.status = text }
                }
            } catch { status = error.localizedDescription }
        }
    }

    func togglePlayback() {
        if isPlaying { stop(); return }
        guard book != nil else { status = "Abra um livro primeiro."; return }
        playTask = Task { [weak self] in
            guard let self else { return }
            isPlaying = true
            defer { isPlaying = false }
            do {
                try await voice.prepare(selectedVoice) { [weak self] text in
                    Task { @MainActor in self?.status = text }
                }
                while !Task.isCancelled, let chapter = self.chapter {
                    guard sentenceIndex < chapter.sentences.count else {
                        if chapterIndex + 1 < (book?.chapters.count ?? 0) {
                            chapterIndex += 1; sentenceIndex = 0; continue
                        }
                        status = "Leitura concluída."; break
                    }
                    status = "Narrando \(chapter.title) — trecho \(sentenceIndex + 1)"
                    try await voice.speak(chapter.sentences[sentenceIndex])
                    sentenceIndex += 1
                    saveProgress()
                }
            } catch { status = error.localizedDescription }
        }
    }

    func stop() {
        playTask?.cancel(); playTask = nil; isPlaying = false
        Task { await voice.stop() }
    }

    func previous() {
        stop()
        if sentenceIndex > 0 { sentenceIndex -= 1 }
        else if chapterIndex > 0 {
            chapterIndex -= 1
            sentenceIndex = max(0, (chapter?.sentences.count ?? 1) - 1)
        }
        saveProgress()
    }

    func next() {
        stop()
        guard let chapter else { return }
        if sentenceIndex + 1 < chapter.sentences.count { sentenceIndex += 1 }
        else if chapterIndex + 1 < (book?.chapters.count ?? 0) { chapterIndex += 1; sentenceIndex = 0 }
        saveProgress()
    }

    func selectChapter(_ index: Int) {
        stop(); chapterIndex = index; sentenceIndex = 0; saveProgress()
    }

    private func saveProgress() {
        guard let book else { return }
        UserDefaults.standard.set(book.name, forKey: "bookName")
        UserDefaults.standard.set(chapterIndex, forKey: "chapterIndex")
        UserDefaults.standard.set(sentenceIndex, forKey: "sentenceIndex")
    }

    private func restoreProgress() {
        guard let book, UserDefaults.standard.string(forKey: "bookName") == book.name else { return }
        chapterIndex = min(UserDefaults.standard.integer(forKey: "chapterIndex"), max(0, book.chapters.count - 1))
        sentenceIndex = min(UserDefaults.standard.integer(forKey: "sentenceIndex"), max(0, (chapter?.sentences.count ?? 1) - 1))
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? { indices.contains(index) ? self[index] : nil }
}
