//
//  WidgetLocalization.swift
//  JoltWidgets
//
//  String localization utilities for Widget Extension
//

import Foundation

// MARK: - String Extension for Widgets

extension String {
    /// Returns the localized version of the string
    /// Widgets run in their own process, so we need to explicitly load from the containing app's bundle
    var widgetLocalized: String {
        // Get current language from shared defaults
        let appGroupID = "group.com.jolt.shared"
        let defaults = UserDefaults(suiteName: appGroupID)
        let lang = defaults?.string(forKey: "app_language") ?? "tr"
        
        // 1. Try widget's localized string first
        let widgetResult = NSLocalizedString(self, comment: "")
        if widgetResult != self { return widgetResult }
        
        // 2. Try current language bundle in widget
        if let widgetPath = Bundle.main.path(forResource: lang, ofType: "lproj"),
           let widgetBundle = Bundle(path: widgetPath) {
            let result = widgetBundle.localizedString(forKey: self, value: nil, table: nil)
            if result != self { return result }
        }
        
        // 3. Fallback to containing app's bundle for the current language
        if let appBundleURL = Bundle.main.bundleURL
            .deletingLastPathComponent() // PlugIns/
            .deletingLastPathComponent() // AppName.app/
            .appendingPathComponent("\(lang).lproj") as URL?,
           let appBundle = Bundle(url: appBundleURL) {
            let result = appBundle.localizedString(forKey: self, value: nil, table: nil)
            if result != self { return result }
        }
        
        // 4. Ultimate fallback to English
        if lang != "en",
           let enBundleURL = Bundle.main.bundleURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("en.lproj") as URL?,
           let enBundle = Bundle(url: enBundleURL) {
            let result = enBundle.localizedString(forKey: self, value: nil, table: nil)
            if result != self { return result }
        }
        
        return self
    }
    
    /// Returns the localized string with format arguments
    func widgetLocalized(with arguments: CVarArg...) -> String {
        String(format: self.widgetLocalized, arguments: arguments)
    }
}

