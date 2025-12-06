//
//  Theme.swift
//  jolt
//
//  Created by Onur Yurdusever on 1.12.2025.
//

import SwiftUI

extension Color {
    static let joltYellow = Color(hex: "#CCFF00")
    
    // MARK: - Dark Mode Colors (Original)
    static let joltBackground = Color(red: 0, green: 0, blue: 0) // Pure black like iOS
    static let joltForeground = Color(red: 1, green: 1, blue: 1) // Pure white
    static let joltCardBackground = Color(red: 0.11, green: 0.11, blue: 0.118) // iOS card background #1C1C1E
    static let joltMuted = Color(red: 0.173, green: 0.173, blue: 0.18) // iOS tertiary #2C2C2E
    static let joltDarkGray = Color(red: 0.173, green: 0.173, blue: 0.18) // Alias for Muted or specific dark gray
    static let joltMutedForeground = Color(red: 0.557, green: 0.557, blue: 0.576) // iOS secondary label #8E8E93
    static let joltBorder = Color(red: 0.22, green: 0.22, blue: 0.227) // iOS separator #383838
    
    // MARK: - Light Mode Colors
    static let joltBackgroundLight = Color(red: 0.95, green: 0.95, blue: 0.97) // iOS systemGroupedBackground #F2F2F7
    static let joltForegroundLight = Color(red: 0, green: 0, blue: 0) // Black text
    static let joltCardBackgroundLight = Color(red: 1, green: 1, blue: 1) // Pure white cards
    static let joltMutedLight = Color(red: 0.90, green: 0.90, blue: 0.92) // iOS tertiarySystemFill
    static let joltMutedForegroundLight = Color(red: 0.24, green: 0.24, blue: 0.26) // iOS secondaryLabel
    static let joltBorderLight = Color(red: 0.78, green: 0.78, blue: 0.80) // iOS separator light
    static let joltYellowDark = Color(hex: "#99CC00") // Darker yellow for light mode contrast
    
    // MARK: - Adaptive Colors (Auto switch based on color scheme)
    static let joltBackgroundAdaptive = Color("joltBackgroundAdaptive", bundle: nil)
    static let joltForegroundAdaptive = Color("joltForegroundAdaptive", bundle: nil)
    static let joltCardBackgroundAdaptive = Color("joltCardBackgroundAdaptive", bundle: nil)
    static let joltMutedAdaptive = Color("joltMutedAdaptive", bundle: nil)
    static let joltMutedForegroundAdaptive = Color("joltMutedForegroundAdaptive", bundle: nil)
    static let joltBorderAdaptive = Color("joltBorderAdaptive", bundle: nil)
    static let joltYellowAdaptive = Color("joltYellowAdaptive", bundle: nil)
    
    // MARK: - Programmatic Adaptive Colors (When Asset Catalog colors aren't set up)
    static func adaptive(light: Color, dark: Color) -> Color {
        Color(UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark
                ? UIColor(dark)
                : UIColor(light)
        })
    }
    
    // Ready-to-use adaptive colors
    static var backgroundAdaptive: Color {
        adaptive(light: joltBackgroundLight, dark: joltBackground)
    }
    
    static var foregroundAdaptive: Color {
        adaptive(light: joltForegroundLight, dark: joltForeground)
    }
    
    static var cardBackgroundAdaptive: Color {
        adaptive(light: joltCardBackgroundLight, dark: joltCardBackground)
    }
    
    static var mutedAdaptive: Color {
        adaptive(light: joltMutedLight, dark: joltMuted)
    }
    
    static var mutedForegroundAdaptive: Color {
        adaptive(light: joltMutedForegroundLight, dark: joltMutedForeground)
    }
    
    static var borderAdaptive: Color {
        adaptive(light: joltBorderLight, dark: joltBorder)
    }
    
    static var accentAdaptive: Color {
        adaptive(light: joltYellowDark, dark: joltYellow)
    }
    
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - SF Pro Font System
extension Font {
    // SF Pro Display - for large titles and headers
    static func sfProDisplay(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        return .system(size: size, weight: weight, design: .default)
    }
    
    // SF Pro Text - for body and UI text
    static func sfProText(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        return .system(size: size, weight: weight, design: .default)
    }
    
    // iOS Typography Scale
    static let iosLargeTitle = Font.system(size: 34, weight: .bold, design: .default)
    static let iosTitle1 = Font.system(size: 28, weight: .bold, design: .default)
    static let iosTitle2 = Font.system(size: 22, weight: .bold, design: .default)
    static let iosTitle3 = Font.system(size: 20, weight: .semibold, design: .default)
    static let iosHeadline = Font.system(size: 17, weight: .semibold, design: .default)
    static let iosBody = Font.system(size: 17, weight: .regular, design: .default)
    static let iosCallout = Font.system(size: 16, weight: .regular, design: .default)
    static let iosSubheadline = Font.system(size: 15, weight: .regular, design: .default)
    static let iosFootnote = Font.system(size: 13, weight: .regular, design: .default)
    static let iosCaption1 = Font.system(size: 12, weight: .regular, design: .default)
    static let iosCaption2 = Font.system(size: 11, weight: .regular, design: .default)
}
