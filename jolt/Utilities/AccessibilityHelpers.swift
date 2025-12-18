//
//  AccessibilityHelpers.swift
//  jolt
//
//  Created for Apple Featured App compliance
//

import SwiftUI

// MARK: - Accessibility Labels
struct A11y {
    
    // MARK: - Focus View
    struct Focus {
        static func bookmarkCard(title: String, domain: String, readingTime: Int) -> String {
            "a11y.focus.bookmarkCard".localized(with: title, domain, readingTime)
        }
        
        static let archiveHint = "a11y.focus.archiveHint".localized
        static let snoozeHint = "a11y.focus.snoozeHint".localized
        static let pullForwardHint = "a11y.focus.pullForwardHint".localized
        static let openReaderHint = "a11y.focus.openReaderHint".localized
        
        static func headerStats(count: Int, totalMinutes: Int) -> String {
            count == 0 
                ? "a11y.focus.headerStats.empty".localized
                : "a11y.focus.headerStats.count".localized(with: count, totalMinutes)
        }
        
        static func filterButton(current: String) -> String {
            "a11y.focus.filterButton".localized(with: current)
        }
    }
    
    // MARK: - Reader View
    struct Reader {
        static func content(title: String, progress: Int) -> String {
            progress > 0
                ? "a11y.reader.contentProgress".localized(with: title, progress)
                : "a11y.reader.content".localized(with: title)
        }
        
        static let joltButton = "a11y.reader.joltButton".localized
        static let joltHint = "a11y.reader.joltHint".localized
        
        static let settingsButton = "a11y.reader.settingsButton".localized
        static let settingsHint = "a11y.reader.settingsHint".localized
        static let shareButton = "a11y.reader.shareButton".localized

        static let starButton = "a11y.reader.starButton".localized
        static let unstarButton = "a11y.reader.unstarButton".localized
        
        static func progressAnnouncement(percent: Int) -> String {
            "a11y.reader.progressAnnouncement".localized(with: percent)
        }
    }
    

    
    // MARK: - Pulse View
    struct Pulse {
        static func streak(days: Int) -> String {
            switch days {
            case 0: return "a11y.pulse.streak.zero".localized
            case 1: return "a11y.pulse.streak.one".localized
            default: return "a11y.pulse.streak.multiple".localized(with: days)
            }
        }
        
        static func stat(label: String, value: String) -> String {
            "a11y.pulse.stat".localized(with: label, value)
        }
        
        static let settingsSection = "a11y.pulse.settingsSection".localized
        static let routinesButton = "a11y.pulse.routinesButton".localized
        static let routinesHint = "a11y.pulse.routinesHint".localized
        static let notificationsButton = "a11y.pulse.notificationsButton".localized
        static let cacheButton = "a11y.pulse.cacheButton".localized
        static let logoutButton = "a11y.pulse.logoutButton".localized
        static let logoutHint = "a11y.pulse.logoutHint".localized
        

    }
    
    // MARK: - Onboarding
    struct Onboarding {
        static let skipButton = "a11y.onboarding.skipButton".localized
        static let nextButton = "a11y.onboarding.nextButton".localized
        static let finishButton = "a11y.onboarding.finishButton".localized
        
        static func step(current: Int, total: Int) -> String {
            "a11y.onboarding.step".localized(with: current, total)
        }
        
        static let permissionPrimary = "a11y.onboarding.permissionPrimary".localized
        static let permissionSecondary = "a11y.onboarding.permissionSecondary".localized
    }
    
    // MARK: - Common
    struct Common {
        static let closeButton = "a11y.common.closeButton".localized
        static let backButton = "a11y.common.backButton".localized
        static let doneButton = "a11y.common.doneButton".localized
        static let cancelButton = "a11y.common.cancelButton".localized
        static let deleteButton = "a11y.common.deleteButton".localized
        static let saveButton = "a11y.common.saveButton".localized
        static let editButton = "a11y.common.editButton".localized
        static let shareButton = "a11y.common.shareButton".localized
        static let moreOptions = "a11y.common.moreOptions".localized
        
        static func loading(item: String) -> String {
            "a11y.common.loading".localized(with: item)
        }
        
        static func error(message: String) -> String {
            "a11y.common.error".localized(with: message)
        }
    }
    
    // MARK: - Share Extension
    struct ShareExtension {
        static let noteField = "a11y.shareExtension.noteField".localized
        static let timeSelection = "a11y.shareExtension.timeSelection".localized

        static let saveButton = "a11y.shareExtension.saveButton".localized
        
        static func timeOption(_ time: String) -> String {
            "a11y.shareExtension.timeOption".localized(with: time)
        }
    }
}

// MARK: - View Extensions for Accessibility

extension View {
    /// Makes a bookmark card fully accessible
    func accessibleBookmarkCard(
        title: String,
        domain: String,
        readingTime: Int,
        isArchived: Bool = false
    ) -> some View {
        self
            .accessibilityElement(children: .combine)
            .accessibilityLabel(A11y.Focus.bookmarkCard(title: title, domain: domain, readingTime: readingTime))
            .accessibilityHint(isArchived ? "" : A11y.Focus.openReaderHint)
            .accessibilityAddTraits(.isButton)
    }
    
    /// Makes any button accessible with label and optional hint
    func accessibleButton(label: String, hint: String? = nil) -> some View {
        let view = self
            .accessibilityLabel(label)
            .accessibilityAddTraits(.isButton)
        
        if let hint = hint {
            return AnyView(view.accessibilityHint(hint))
        }
        return AnyView(view)
    }
    
    /// Makes a header accessible
    func accessibleHeader(_ text: String) -> some View {
        self
            .accessibilityLabel(text)
            .accessibilityAddTraits(.isHeader)
    }
    
    /// Announces a value change to VoiceOver
    func accessibilityAnnounce(_ message: String) {
        AccessibilityNotification.Announcement(message).post()
    }
    
    /// Groups children for better VoiceOver navigation
    func accessibleGroup(label: String) -> some View {
        self
            .accessibilityElement(children: .contain)
            .accessibilityLabel(label)
    }
    
    /// Hides decorative elements from VoiceOver
    func accessibilityDecorative() -> some View {
        self.accessibilityHidden(true)
    }
}

// MARK: - Dynamic Type Support

/// A modifier that scales font size based on Dynamic Type settings
struct ScaledFont: ViewModifier {
    @Environment(\.dynamicTypeSize) var dynamicTypeSize
    
    let baseSize: CGFloat
    let weight: Font.Weight
    let design: Font.Design
    let maxSize: CGFloat?
    
    init(size: CGFloat, weight: Font.Weight = .regular, design: Font.Design = .default, maxSize: CGFloat? = nil) {
        self.baseSize = size
        self.weight = weight
        self.design = design
        self.maxSize = maxSize
    }
    
    func body(content: Content) -> some View {
        content
            .font(.system(size: scaledSize, weight: weight, design: design))
    }
    
    private var scaledSize: CGFloat {
        let scaled: CGFloat
        switch dynamicTypeSize {
        case .xSmall: scaled = baseSize * 0.8
        case .small: scaled = baseSize * 0.9
        case .medium: scaled = baseSize
        case .large: scaled = baseSize * 1.1
        case .xLarge: scaled = baseSize * 1.2
        case .xxLarge: scaled = baseSize * 1.3
        case .xxxLarge: scaled = baseSize * 1.4
        case .accessibility1: scaled = baseSize * 1.6
        case .accessibility2: scaled = baseSize * 1.8
        case .accessibility3: scaled = baseSize * 2.0
        case .accessibility4: scaled = baseSize * 2.2
        case .accessibility5: scaled = baseSize * 2.4
        @unknown default: scaled = baseSize
        }
        
        if let maxSize = maxSize {
            return min(scaled, maxSize)
        }
        return scaled
    }
}

extension View {
    /// Applies a scaled font that respects Dynamic Type
    func scaledFont(
        size: CGFloat,
        weight: Font.Weight = .regular,
        design: Font.Design = .default,
        maxSize: CGFloat? = nil
    ) -> some View {
        modifier(ScaledFont(size: size, weight: weight, design: design, maxSize: maxSize))
    }
}

// MARK: - Scaled Metrics for Layout

/// Common scaled metrics for consistent spacing
struct ScaledMetrics {
    @ScaledMetric(relativeTo: .body) var standardPadding: CGFloat = 16
    @ScaledMetric(relativeTo: .body) var smallPadding: CGFloat = 8
    @ScaledMetric(relativeTo: .body) var largePadding: CGFloat = 24
    @ScaledMetric(relativeTo: .body) var cardHeight: CGFloat = 80
    @ScaledMetric(relativeTo: .body) var thumbnailSize: CGFloat = 60
    @ScaledMetric(relativeTo: .body) var iconSize: CGFloat = 24
    @ScaledMetric(relativeTo: .body) var buttonHeight: CGFloat = 44
}

// MARK: - Reduce Motion Support

extension View {
    /// Applies animation only if user hasn't enabled Reduce Motion
    func animationRespectingMotion<V: Equatable>(_ animation: Animation?, value: V) -> some View {
        self.modifier(ReduceMotionModifier(animation: animation, value: value))
    }
}

struct ReduceMotionModifier<V: Equatable>: ViewModifier {
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    let animation: Animation?
    let value: V
    
    func body(content: Content) -> some View {
        if reduceMotion {
            content
        } else {
            content.animation(animation, value: value)
        }
    }
}

// MARK: - High Contrast Support

extension View {
    /// Adjusts colors for high contrast mode
    func highContrastAware(normalColor: Color, highContrastColor: Color) -> some View {
        self.modifier(HighContrastModifier(normalColor: normalColor, highContrastColor: highContrastColor))
    }
}

struct HighContrastModifier: ViewModifier {
    @Environment(\.accessibilityDifferentiateWithoutColor) var differentiateWithoutColor
    let normalColor: Color
    let highContrastColor: Color
    
    func body(content: Content) -> some View {
        content.foregroundColor(differentiateWithoutColor ? highContrastColor : normalColor)
    }
}

// MARK: - Preview Helper

#Preview("Accessibility Test") {
    VStack(spacing: 20) {
        Text("Dynamic Type Test")
            .scaledFont(size: 17, weight: .semibold)
        
        Button("Accessible Button") {}
            .accessibleButton(label: A11y.Common.saveButton, hint: "Saves your changes")
        
        Text(A11y.Focus.headerStats(count: 5, totalMinutes: 23))
            .scaledFont(size: 14)
            .foregroundColor(.secondary)
    }
    .padding()
}
