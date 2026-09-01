import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @EnvironmentObject private var model: ReaderViewModel

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 14) {
                        headerCard
                        voiceCard
                        chaptersCard
                        progressCard
                        readerCard
                    }
                    .padding()
                }
                playerBar
            }
            .background(Color.black)
            .navigationTitle("Audiobook Reviewer")
            .navigationBarTitleDisplayMode(.inline)
            .fileImporter(isPresented: $model.showImporter,
                          allowedContentTypes: [.pdf, .plainText, UTType(filenameExtension: "docx")!]) { result in
                if case .success(let url) = result { model.importFile(url) }
                else if case .failure(let error) = result { model.status = error.localizedDescription }
            }
        }
        .tint(Color(red: 0.86, green: 0.70, blue: 0.39))
    }

    private var headerCard: some View {
        card {
            Button { model.showImporter = true } label: {
                Label("Abrir PDF, DOCX ou TXT", systemImage: "book")
                    .font(.headline).frame(maxWidth: .infinity).padding()
            }
            .buttonStyle(.borderedProminent)
            Text(model.status).font(.footnote).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var voiceCard: some View {
        card {
            HStack {
                VStack(alignment: .leading) {
                    Text("Voz neural local").font(.headline)
                    Text("Piper • pt-BR • sem API").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                if model.isPreparingVoice { ProgressView() }
            }
            Picker("Voz", selection: $model.selectedVoice) {
                ForEach(PiperVoiceService.Voice.allCases) { v in Text(v.title).tag(v) }
            }
            .pickerStyle(.segmented)
            Button("Baixar / preparar voz") { model.prepareVoice() }
                .buttonStyle(.bordered)
        }
    }

    private var chaptersCard: some View {
        card {
            Text("Capítulos").font(.headline).frame(maxWidth: .infinity, alignment: .leading)
            if let book = model.book {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(Array(book.chapters.enumerated()), id: \.element.id) { index, chapter in
                            Button("\(index + 1). \(chapter.title)") { model.selectChapter(index) }
                                .buttonStyle(.bordered)
                                .tint(index == model.chapterIndex ? .yellow : .gray)
                        }
                    }
                }
            } else { Text("Nenhum livro carregado.").foregroundStyle(.secondary) }
        }
    }

    private var progressCard: some View {
        card {
            ProgressView(value: model.progress)
            HStack {
                Text("\(Int(model.progress * 100))%")
                Spacer()
                if let c = model.chapter { Text("\(model.chapterIndex + 1) • \(model.sentenceIndex + 1)/\(c.sentences.count)") }
            }
            .font(.caption).foregroundStyle(.secondary)
        }
    }

    private var readerCard: some View {
        card {
            Text(model.chapter?.title ?? "Leitor").font(.title2.bold()).frame(maxWidth: .infinity, alignment: .leading)
            if let chapter = model.chapter {
                LazyVStack(alignment: .leading, spacing: 10) {
                    ForEach(Array(chapter.sentences.enumerated()), id: \.offset) { index, sentence in
                        Text(sentence)
                            .font(.system(size: 20, design: .serif))
                            .foregroundStyle(index < model.sentenceIndex ? .secondary : .primary)
                            .padding(6)
                            .background(index == model.sentenceIndex ? Color.yellow.opacity(0.18) : .clear, in: RoundedRectangle(cornerRadius: 7))
                            .onTapGesture { model.stop(); model.sentenceIndex = index }
                    }
                }
            } else { Text("Abra um manuscrito para começar.").foregroundStyle(.secondary) }
        }
    }

    private var playerBar: some View {
        HStack(spacing: 12) {
            Button(action: model.previous) { Image(systemName: "backward.fill").frame(width: 52, height: 48) }.buttonStyle(.bordered)
            Button(action: model.togglePlayback) {
                Label(model.isPlaying ? "Parar" : "Ouvir", systemImage: model.isPlaying ? "stop.fill" : "play.fill")
                    .frame(maxWidth: .infinity, minHeight: 48).font(.headline)
            }.buttonStyle(.borderedProminent)
            Button(action: model.next) { Image(systemName: "forward.fill").frame(width: 52, height: 48) }.buttonStyle(.bordered)
        }
        .padding().background(.ultraThinMaterial)
    }

    private func card<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12, content: content)
            .padding().frame(maxWidth: .infinity)
            .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.10)))
    }
}
