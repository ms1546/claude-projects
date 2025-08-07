//
//  CharacterStyleTests.swift
//  TrainAlertTests
//
//  Created by Claude on 2024/01/08.
//

import XCTest
@testable import TrainAlert

final class CharacterStyleTests: XCTestCase {
    
    // MARK: - Basic Functionality Tests
    
    func testAllCharacterStylesCases() {
        let allCases = CharacterStyle.allCases
        let expectedCount = 6 // gyaru, butler, kansai, tsundere, sporty, healing
        
        XCTAssertEqual(allCases.count, expectedCount, "Should have exactly 6 character styles")
        
        // Test all expected cases exist
        XCTAssertTrue(allCases.contains(.gyaru))
        XCTAssertTrue(allCases.contains(.butler))
        XCTAssertTrue(allCases.contains(.kansai))
        XCTAssertTrue(allCases.contains(.tsundere))
        XCTAssertTrue(allCases.contains(.sporty))
        XCTAssertTrue(allCases.contains(.healing))
    }
    
    func testRawValues() {
        XCTAssertEqual(CharacterStyle.gyaru.rawValue, "gyaru")
        XCTAssertEqual(CharacterStyle.butler.rawValue, "butler")
        XCTAssertEqual(CharacterStyle.kansai.rawValue, "kansai")
        XCTAssertEqual(CharacterStyle.tsundere.rawValue, "tsundere")
        XCTAssertEqual(CharacterStyle.sporty.rawValue, "sporty")
        XCTAssertEqual(CharacterStyle.healing.rawValue, "healing")
    }
    
    func testDisplayNames() {
        XCTAssertEqual(CharacterStyle.gyaru.displayName, "ギャル系")
        XCTAssertEqual(CharacterStyle.butler.displayName, "執事系")
        XCTAssertEqual(CharacterStyle.kansai.displayName, "関西弁系")
        XCTAssertEqual(CharacterStyle.tsundere.displayName, "ツンデレ系")
        XCTAssertEqual(CharacterStyle.sporty.displayName, "体育会系")
        XCTAssertEqual(CharacterStyle.healing.displayName, "癒し系")
    }
    
    // MARK: - System Prompt Tests
    
    func testSystemPromptsNotEmpty() {
        for style in CharacterStyle.allCases {
            XCTAssertFalse(style.systemPrompt.isEmpty, "System prompt should not be empty for \(style.displayName)")
            XCTAssertGreaterThan(style.systemPrompt.count, 50, "System prompt should be detailed for \(style.displayName)")
        }
    }
    
    func testGyaruSystemPrompt() {
        let prompt = CharacterStyle.gyaru.systemPrompt
        
        // Should contain characteristics specific to gyaru style
        XCTAssertTrue(prompt.contains("ギャル系"), "Should mention gyaru style")
        XCTAssertTrue(prompt.contains("明るく"), "Should mention brightness")
        XCTAssertTrue(prompt.contains("だよ"), "Should include typical gyaru expressions")
        XCTAssertTrue(prompt.contains("テンション"), "Should mention high tension")
    }
    
    func testButlerSystemPrompt() {
        let prompt = CharacterStyle.butler.systemPrompt
        
        // Should contain characteristics specific to butler style
        XCTAssertTrue(prompt.contains("執事"), "Should mention butler")
        XCTAssertTrue(prompt.contains("礼儀正しく"), "Should mention politeness")
        XCTAssertTrue(prompt.contains("敬語"), "Should mention formal language")
        XCTAssertTrue(prompt.contains("でございます"), "Should include typical butler expressions")
    }
    
    func testKansaiSystemPrompt() {
        let prompt = CharacterStyle.kansai.systemPrompt
        
        // Should contain characteristics specific to Kansai dialect
        XCTAssertTrue(prompt.contains("関西弁"), "Should mention Kansai dialect")
        XCTAssertTrue(prompt.contains("やで"), "Should include typical Kansai expressions")
        XCTAssertTrue(prompt.contains("親しみやすい"), "Should mention friendliness")
        XCTAssertTrue(prompt.contains("あかん"), "Should include Kansai vocabulary")
    }
    
    func testTsundereSystemPrompt() {
        let prompt = CharacterStyle.tsundere.systemPrompt
        
        // Should contain characteristics specific to tsundere style
        XCTAssertTrue(prompt.contains("ツンデレ"), "Should mention tsundere")
        XCTAssertTrue(prompt.contains("ツン"), "Should mention tsun attitude")
        XCTAssertTrue(prompt.contains("別に"), "Should include typical tsundere expressions")
        XCTAssertTrue(prompt.contains("心配"), "Should mention caring underneath")
    }
    
    func testSportySystemPrompt() {
        let prompt = CharacterStyle.sporty.systemPrompt
        
        // Should contain characteristics specific to sporty style
        XCTAssertTrue(prompt.contains("体育会系"), "Should mention athletic style")
        XCTAssertTrue(prompt.contains("ハキハキ"), "Should mention energetic speech")
        XCTAssertTrue(prompt.contains("頑張"), "Should include encouraging expressions")
        XCTAssertTrue(prompt.contains("元気"), "Should mention energy")
    }
    
    func testHealingSystemPrompt() {
        let prompt = CharacterStyle.healing.systemPrompt
        
        // Should contain characteristics specific to healing style
        XCTAssertTrue(prompt.contains("癒し系"), "Should mention healing style")
        XCTAssertTrue(prompt.contains("穏やか"), "Should mention calmness")
        XCTAssertTrue(prompt.contains("優しい"), "Should mention gentleness")
        XCTAssertTrue(prompt.contains("安心"), "Should mention comfort")
    }
    
    // MARK: - Tone Tests
    
    func testTonesNotEmpty() {
        for style in CharacterStyle.allCases {
            XCTAssertFalse(style.tone.isEmpty, "Tone should not be empty for \(style.displayName)")
        }
    }
    
    func testToneDescriptions() {
        XCTAssertTrue(CharacterStyle.gyaru.tone.contains("テンション"))
        XCTAssertTrue(CharacterStyle.butler.tone.contains("敬語"))
        XCTAssertTrue(CharacterStyle.kansai.tone.contains("関西弁"))
        XCTAssertTrue(CharacterStyle.tsundere.tone.contains("ツンデレ"))
        XCTAssertTrue(CharacterStyle.sporty.tone.contains("体育会系"))
        XCTAssertTrue(CharacterStyle.healing.tone.contains("癒し系"))
    }
    
    // MARK: - Fallback Messages Tests
    
    func testFallbackMessagesStructure() {
        for style in CharacterStyle.allCases {
            let messages = style.fallbackMessages
            
            // Test train alert message structure
            XCTAssertFalse(messages.trainAlert.title.isEmpty, "Train alert title should not be empty for \(style.displayName)")
            XCTAssertFalse(messages.trainAlert.body.isEmpty, "Train alert body should not be empty for \(style.displayName)")
            
            // Test location alert message structure
            XCTAssertFalse(messages.locationAlert.title.isEmpty, "Location alert title should not be empty for \(style.displayName)")
            XCTAssertFalse(messages.locationAlert.body.isEmpty, "Location alert body should not be empty for \(style.displayName)")
            
            // Test snooze alert message structure
            XCTAssertFalse(messages.snoozeAlert.title.isEmpty, "Snooze alert title should not be empty for \(style.displayName)")
            XCTAssertFalse(messages.snoozeAlert.body.isEmpty, "Snooze alert body should not be empty for \(style.displayName)")
        }
    }
    
    func testPlaceholdersInFallbackMessages() {
        for style in CharacterStyle.allCases {
            let messages = style.fallbackMessages
            
            // Train alert should have {station} placeholder
            XCTAssertTrue(messages.trainAlert.body.contains("{station}"), 
                         "Train alert body should contain {station} placeholder for \(style.displayName)")
            
            // Location alert should have {station} placeholder
            XCTAssertTrue(messages.locationAlert.body.contains("{station}"), 
                         "Location alert body should contain {station} placeholder for \(style.displayName)")
            
            // Snooze alert should have both {station} and {count} placeholders
            XCTAssertTrue(messages.snoozeAlert.body.contains("{station}"), 
                         "Snooze alert body should contain {station} placeholder for \(style.displayName)")
            XCTAssertTrue(messages.snoozeAlert.body.contains("{count}"), 
                         "Snooze alert body should contain {count} placeholder for \(style.displayName)")
        }
    }
    
    func testGyaruFallbackMessages() {
        let messages = CharacterStyle.gyaru.fallbackMessages
        
        // Should contain gyaru-style expressions
        XCTAssertTrue(messages.trainAlert.body.contains("だよ") || messages.trainAlert.body.contains("じゃん"))
        XCTAssertTrue(messages.locationAlert.body.contains("だよ") || messages.locationAlert.body.contains("じゃん"))
        XCTAssertTrue(messages.snoozeAlert.body.contains("だよ") || messages.snoozeAlert.body.contains("って"))
    }
    
    func testButlerFallbackMessages() {
        let messages = CharacterStyle.butler.fallbackMessages
        
        // Should contain butler-style expressions
        XCTAssertTrue(messages.trainAlert.body.contains("いたします") || messages.trainAlert.body.contains("ございます"))
        XCTAssertTrue(messages.locationAlert.body.contains("いたします") || messages.locationAlert.body.contains("ございます"))
        XCTAssertTrue(messages.snoozeAlert.body.contains("ございます") || messages.snoozeAlert.body.contains("いたします"))
    }
    
    func testKansaiFallbackMessages() {
        let messages = CharacterStyle.kansai.fallbackMessages
        
        // Should contain Kansai dialect expressions
        XCTAssertTrue(messages.trainAlert.body.contains("やで") || messages.trainAlert.body.contains("あかん"))
        XCTAssertTrue(messages.locationAlert.body.contains("やで") || messages.locationAlert.body.contains("で〜"))
        XCTAssertTrue(messages.snoozeAlert.body.contains("やで") || messages.snoozeAlert.body.contains("あかん"))
    }
    
    // MARK: - Codable Tests
    
    func testCharacterStyleCodable() throws {
        for style in CharacterStyle.allCases {
            // Test encoding
            let encoded = try JSONEncoder().encode(style)
            XCTAssertFalse(encoded.isEmpty, "Encoded data should not be empty for \(style.displayName)")
            
            // Test decoding
            let decoded = try JSONDecoder().decode(CharacterStyle.self, from: encoded)
            XCTAssertEqual(decoded, style, "Decoded style should match original for \(style.displayName)")
        }
    }
    
    func testFallbackMessagesCodable() throws {
        for style in CharacterStyle.allCases {
            let messages = style.fallbackMessages
            
            // Test that fallback messages structure is encodable
            let encoded = try JSONEncoder().encode(messages)
            XCTAssertFalse(encoded.isEmpty, "Encoded fallback messages should not be empty for \(style.displayName)")
            
            let decoded = try JSONDecoder().decode(FallbackMessages.self, from: encoded)
            XCTAssertEqual(decoded.trainAlert.title, messages.trainAlert.title)
            XCTAssertEqual(decoded.trainAlert.body, messages.trainAlert.body)
            XCTAssertEqual(decoded.locationAlert.title, messages.locationAlert.title)
            XCTAssertEqual(decoded.locationAlert.body, messages.locationAlert.body)
            XCTAssertEqual(decoded.snoozeAlert.title, messages.snoozeAlert.title)
            XCTAssertEqual(decoded.snoozeAlert.body, messages.snoozeAlert.body)
        }
    }
    
    // MARK: - Performance Tests
    
    func testCharacterStylePerformance() {
        measure {
            for _ in 0..<1000 {
                for style in CharacterStyle.allCases {
                    _ = style.systemPrompt
                    _ = style.tone
                    _ = style.displayName
                    _ = style.fallbackMessages
                }
            }
        }
    }
    
    // MARK: - Edge Cases
    
    func testCharacterStyleFromRawValue() {
        // Test valid raw values
        XCTAssertEqual(CharacterStyle(rawValue: "gyaru"), .gyaru)
        XCTAssertEqual(CharacterStyle(rawValue: "butler"), .butler)
        XCTAssertEqual(CharacterStyle(rawValue: "kansai"), .kansai)
        XCTAssertEqual(CharacterStyle(rawValue: "tsundere"), .tsundere)
        XCTAssertEqual(CharacterStyle(rawValue: "sporty"), .sporty)
        XCTAssertEqual(CharacterStyle(rawValue: "healing"), .healing)
        
        // Test invalid raw values
        XCTAssertNil(CharacterStyle(rawValue: "invalid"))
        XCTAssertNil(CharacterStyle(rawValue: ""))
        XCTAssertNil(CharacterStyle(rawValue: "GYARU"))
    }
}
