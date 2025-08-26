//
//  CharacterStyle+Extensions.swift
//  TrainAlert
//
//  Created by Claude on 2025/08/26.
//

import Foundation

extension CharacterStyle {
    var emoji: String {
        switch self {
        case .healing:
            return "😊"
        case .gyaru:
            return "🎉"
        case .butler:
            return "🤵"
        case .sporty:
            return "💪"
        case .tsundere:
            return "😤"
        case .kansai:
            return "😆"
        }
    }
    
    var description: String {
        switch self {
        case .healing:
            return "優しい"
        case .gyaru:
            return "ギャル"
        case .butler:
            return "執事"
        case .sporty:
            return "元気"
        case .tsundere:
            return "ツンデレ"
        case .kansai:
            return "関西弁"
        }
    }
    
    // Legacy support for old character styles
    static let friendly = CharacterStyle.healing
    static let polite = CharacterStyle.butler
    static let motivational = CharacterStyle.sporty
    static let funny = CharacterStyle.kansai
}
