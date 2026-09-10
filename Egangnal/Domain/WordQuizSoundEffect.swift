//
//  WordQuizSoundEffect.swift
//  Egangnal
//

import Foundation

enum WordQuizSoundEffect: String, CaseIterable, Identifiable, Sendable {
    case off
    case sound1
    case sound2

    var id: Self { self }
}
