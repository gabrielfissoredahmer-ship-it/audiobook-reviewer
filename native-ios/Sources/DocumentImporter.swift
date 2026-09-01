import Foundation
import PDFKit
import ZIPFoundation

struct DocumentImporter {
    static func read(url: URL) throws -> String {
        let ext = url.pathExtension.lowercased()
        switch ext {
        case "txt":
            return try String(contentsOf: url, encoding: .utf8)
        case "pdf":
            guard let pdf = PDFDocument(url: url) else { throw ImportError.invalidPDF }
            return (0..<pdf.pageCount).compactMap { pdf.page(at: $0)?.string }.joined(separator: "\n\n")
        case "docx":
            return try readDOCX(url: url)
        default:
            throw ImportError.unsupported
        }
    }

    private static func readDOCX(url: URL) throws -> String {
        let archive = try Archive(url: url, accessMode: .read)
        guard let entry = archive["word/document.xml"] else { throw ImportError.invalidDOCX }
        var data = Data()
        _ = try archive.extract(entry) { chunk in data.append(chunk) }
        let delegate = DOCXTextDelegate()
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        guard parser.parse() else { throw ImportError.invalidDOCX }
        return delegate.text
    }

    enum ImportError: LocalizedError {
        case unsupported, invalidPDF, invalidDOCX
        var errorDescription: String? {
            switch self {
            case .unsupported: return "Formato não suportado. Use PDF, DOCX ou TXT."
            case .invalidPDF: return "Não foi possível ler o PDF."
            case .invalidDOCX: return "Não foi possível extrair o texto do DOCX."
            }
        }
    }
}

private final class DOCXTextDelegate: NSObject, XMLParserDelegate {
    private var insideText = false
    private var parts: [String] = []
    var text: String { parts.joined(separator: " ") }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        if elementName == "w:t" || elementName.hasSuffix(":t") { insideText = true }
        if elementName == "w:p" || elementName.hasSuffix(":p") { parts.append("\n") }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if insideText { parts.append(string) }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        if elementName == "w:t" || elementName.hasSuffix(":t") { insideText = false }
    }
}
