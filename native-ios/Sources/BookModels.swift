import Foundation

struct BookChapter: Identifiable, Codable, Hashable {
    let id: UUID
    let title: String
    let sentences: [String]

    init(id: UUID = UUID(), title: String, sentences: [String]) {
        self.id = id
        self.title = title
        self.sentences = sentences
    }
}

struct BookDocument: Codable {
    let name: String
    let chapters: [BookChapter]
}

enum BookParser {
    static func makeBook(name: String, text raw: String) -> BookDocument {
        let text = clean(raw)
        let lines = text.components(separatedBy: .newlines)
        let regex = try! NSRegularExpression(pattern: "^(CAP[IÍ]TULO|PR[ÓO]LOGO|EP[IÍ]LOGO|PARTE)\\b.{0,100}$", options: [.caseInsensitive])
        var markers: [(Int, String)] = []

        for (index, line) in lines.enumerated() {
            let title = line.trimmingCharacters(in: .whitespacesAndNewlines)
            let range = NSRange(title.startIndex..<title.endIndex, in: title)
            if regex.firstMatch(in: title, range: range) != nil {
                markers.append((index, title))
            }
        }

        guard !markers.isEmpty else {
            return BookDocument(name: name, chapters: [BookChapter(title: "Livro completo", sentences: splitSentences(text))])
        }

        var chapters: [BookChapter] = []
        if markers[0].0 > 0 {
            let intro = lines[0..<markers[0].0].joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            if intro.count > 40 { chapters.append(BookChapter(title: "Abertura", sentences: splitSentences(intro))) }
        }

        for i in markers.indices {
            let start = markers[i].0
            let end = i < markers.count - 1 ? markers[i + 1].0 : lines.count
            let body = lines[start..<end].joined(separator: "\n")
            chapters.append(BookChapter(title: markers[i].1, sentences: splitSentences(body)))
        }
        return BookDocument(name: name, chapters: chapters)
    }

    private static func clean(_ text: String) -> String {
        text.replacingOccurrences(of: "\r", with: "")
            .replacingOccurrences(of: "[ \\t]+\\n", with: "\n", options: .regularExpression)
            .replacingOccurrences(of: "\\n{4,}", with: "\n\n\n", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func splitSentences(_ text: String) -> [String] {
        let pattern = "[^.!?…\\n]+(?:[.!?…]+[\\\"'”’)]*|\\n+|$)"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [text] }
        let ns = text as NSString
        return regex.matches(in: text, range: NSRange(location: 0, length: ns.length))
            .map { ns.substring(with: $0.range).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}
