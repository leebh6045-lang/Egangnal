//
//  WordBookTemplateDocument.swift
//  Egangnal
//

import SwiftUI
import UniformTypeIdentifiers

enum WordBookFileType {
    // macOS 15 SDK 没有公开 UTType.markdown，统一从标准 .md 扩展名解析。
    static let markdown = UTType(filenameExtension: "md", conformingTo: .plainText)!
}

struct WordBookTemplateDocument: FileDocument {
    static var readableContentTypes: [UTType] {
        [WordBookFileType.markdown]
    }

    var text: String

    init(text: String) {
        self.text = text
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents,
              let text = String(data: data, encoding: .utf8) else {
            self.text = ""
            return
        }
        self.text = text
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: Data(text.utf8))
    }
}
