//
//  LanguageSpace.swift
//  Egangnal
//

enum LanguageSpace: String, CaseIterable, Identifiable, Hashable, Sendable {
    case japanese
    case english

    var id: Self { self }

    var title: String {
        switch self {
        case .japanese:
            "日语"
        case .english:
            "英语"
        }
    }

    var nativeTitle: String {
        switch self {
        case .japanese:
            "日本語"
        case .english:
            "English"
        }
    }

    var coverImageName: String {
        switch self {
        case .japanese:
            "JapaneseCover"
        case .english:
            "EnglishCover"
        }
    }

    var companion: LanguageSpace {
        switch self {
        case .japanese:
            .english
        case .english:
            .japanese
        }
    }
}
