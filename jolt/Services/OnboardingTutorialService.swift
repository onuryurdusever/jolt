//
//  OnboardingTutorialService.swift
//  jolt
//
//  Creates tutorial bookmark cards for new users
//

import SwiftData
import Foundation

/// Service to create tutorial bookmarks for new users
@MainActor
class OnboardingTutorialService {
    static let shared = OnboardingTutorialService()
    
    private let tutorialCardsCreatedKey = "tutorialCardsCreated"
    
    private init() {}
    
    /// Check if tutorial cards have been created
    var hasCreatedTutorialCards: Bool {
        UserDefaults.standard.bool(forKey: tutorialCardsCreatedKey)
    }
    
    /// Create 4 tutorial bookmark cards for new users
    func createTutorialCards(modelContext: ModelContext, userID: String) {
        // Don't create if already done
        guard !hasCreatedTutorialCards else { return }
        
        let cards = getTutorialCards(userID: userID)
        
        for card in cards {
            modelContext.insert(card)
        }
        
        do {
            try modelContext.save()
            UserDefaults.standard.set(true, forKey: tutorialCardsCreatedKey)
            print("✅ Created \(cards.count) tutorial cards for new user")
        } catch {
            print("❌ Failed to create tutorial cards: \(error)")
        }
    }
    
    /// Get the 4 tutorial bookmark cards
    private func getTutorialCards(userID: String) -> [Bookmark] {
        let now = Date()
        
        return [
            // Card 1: Manifesto
            Bookmark(
                userID: userID,
                originalURL: "jolt://tutorial/manifesto",
                scheduledFor: now,
                contentHTML: generateManifestoHTML(),
                title: "tutorial.manifesto.title".localized,
                excerpt: "tutorial.manifesto.excerpt".localized,
                coverImage: nil,
                readingTimeMinutes: 1,
                type: .article,
                domain: "Jolt",
                userNote: nil,
                metadata: ["tag": "#Felsefe", "tutorial": "1"]
            ),
            
            // Card 2: Setup (Most Critical)
            Bookmark(
                userID: userID,
                originalURL: "jolt://tutorial/setup",
                scheduledFor: now.addingTimeInterval(1), // 1 second later to ensure order
                contentHTML: generateSetupHTML(),
                title: "tutorial.setup.title".localized,
                excerpt: "tutorial.setup.excerpt".localized,
                coverImage: nil,
                readingTimeMinutes: 1,
                type: .article,
                domain: "Jolt",
                userNote: nil,
                metadata: ["tag": "#Kurulum", "tutorial": "2"]
            ),
            
            // Card 3: Discipline
            Bookmark(
                userID: userID,
                originalURL: "jolt://tutorial/discipline",
                scheduledFor: now.addingTimeInterval(2),
                contentHTML: generateDisciplineHTML(),
                title: "tutorial.discipline.title".localized,
                excerpt: "tutorial.discipline.excerpt".localized,
                coverImage: nil,
                readingTimeMinutes: 1,
                type: .article,
                domain: "Jolt",
                userNote: nil,
                metadata: ["tag": "#Alışkanlık", "tutorial": "3"]
            ),
            
            // Card 4: Mastery
            Bookmark(
                userID: userID,
                originalURL: "jolt://tutorial/mastery",
                scheduledFor: now.addingTimeInterval(3),
                contentHTML: generateMasteryHTML(),
                title: "tutorial.mastery.title".localized,
                excerpt: "tutorial.mastery.excerpt".localized,
                coverImage: nil,
                readingTimeMinutes: 1,
                type: .article,
                domain: "Jolt",
                userNote: nil,
                metadata: ["tag": "#HandsFree", "tutorial": "4"]
            )
        ]
    }
    
    // MARK: - HTML Content Generators
    
    private func generateManifestoHTML() -> String {
        """
        <article>
            <h1>📜 \("tutorial.manifesto.h1".localized)</h1>
            
            <p><strong>\("tutorial.manifesto.welcome".localized)</strong></p>
            
            <p>\("tutorial.manifesto.intro".localized)</p>
            
            <p>\("tutorial.manifesto.camp".localized)</p>
            
            <h2>⚡ \("tutorial.manifesto.rule1.title".localized)</h2>
            <p>\("tutorial.manifesto.rule1.desc".localized)</p>
            
            <h2>🔥 \("tutorial.manifesto.rule2.title".localized)</h2>
            <p>\("tutorial.manifesto.rule2.desc".localized)</p>
            
            <h2>🎯 \("tutorial.manifesto.rule3.title".localized)</h2>
            <p>\("tutorial.manifesto.rule3.desc".localized)</p>
            
            <hr>
            
            <p>\("tutorial.manifesto.breath".localized)</p>
            
            <p><strong>\("tutorial.manifesto.cta".localized)</strong></p>
        </article>
        """
    }
    
    private func generateSetupHTML() -> String {
        """
        <article>
            <h1>⚙️ \("tutorial.setup.h1".localized)</h1>
            
            <p>\("tutorial.setup.intro".localized)</p>
            
            <p>\("tutorial.setup.problem".localized)</p>
            
            <h2>📱 \("tutorial.setup.action.title".localized)</h2>
            
            <ol>
                <li>\("tutorial.setup.step1".localized)</li>
                <li>\("tutorial.setup.step2".localized)</li>
                <li>\("tutorial.setup.step3".localized)</li>
                <li>\("tutorial.setup.step4".localized)</li>
                <li><strong>\("tutorial.setup.step5".localized)</strong></li>
            </ol>
            
            <hr>
            
            <p>\("tutorial.setup.done".localized)</p>
            
            <p><em>\("tutorial.setup.cta".localized)</em></p>
        </article>
        """
    }
    
    private func generateDisciplineHTML() -> String {
        """
        <article>
            <h1>🛡️ \("tutorial.discipline.h1".localized)</h1>
            
            <p>\("tutorial.discipline.streak".localized)</p>
            
            <p>\("tutorial.discipline.break".localized)</p>
            
            <p>\("tutorial.discipline.purpose".localized)</p>
            
            <h2>📲 \("tutorial.discipline.widget.title".localized)</h2>
            
            <p>\("tutorial.discipline.widget.intro".localized)</p>
            
            <p>\("tutorial.discipline.widget.benefits".localized)</p>
            <ul>
                <li>\("tutorial.discipline.widget.benefit1".localized)</li>
                <li>\("tutorial.discipline.widget.benefit2".localized)</li>
                <li>\("tutorial.discipline.widget.benefit3".localized)</li>
            </ul>
            
            <hr>
            
            <p><strong>\("tutorial.discipline.reminder".localized)</strong></p>
            
            <p>\("tutorial.discipline.cta".localized)</p>
        </article>
        """
    }
    
    private func generateMasteryHTML() -> String {
        """
        <article>
            <h1>🎙️ \("tutorial.mastery.h1".localized)</h1>
            
            <p>\("tutorial.mastery.intro".localized)</p>
            
            <p>\("tutorial.mastery.siri".localized)</p>
            
            <h2>🗣️ \("tutorial.mastery.ask.title".localized)</h2>
            
            <p><strong>\("tutorial.mastery.cmd1".localized)</strong><br>
            👉 \("tutorial.mastery.cmd1.desc".localized)</p>
            
            <p><strong>\("tutorial.mastery.cmd2".localized)</strong><br>
            👉 \("tutorial.mastery.cmd2.desc".localized)</p>
            
            <hr>
            
            <p>\("tutorial.mastery.philosophy".localized)</p>
            
            <h2>🎉 \("tutorial.mastery.congrats".localized)</h2>
            
            <p>\("tutorial.mastery.complete".localized)</p>
            
            <p>\("tutorial.mastery.next".localized)</p>
            
            <p><em>\("tutorial.mastery.timer".localized)</em></p>
        </article>
        """
    }
}
