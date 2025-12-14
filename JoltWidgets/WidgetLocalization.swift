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
    var localized: String {
        // First try the widget's own bundle
        let widgetResult = NSLocalizedString(self, comment: "")
        if widgetResult != self { return widgetResult }
        
        // Fallback 1: Try widget's tr.lproj
        if let widgetPath = Bundle.main.path(forResource: "tr", ofType: "lproj"),
           let widgetBundle = Bundle(path: widgetPath) {
            let result = widgetBundle.localizedString(forKey: self, value: nil, table: nil)
            if result != self { return result }
        }
        
        // Fallback 2: Try to get the containing app's bundle
        // Widget bundle is at: AppName.app/PlugIns/WidgetExtension.appex
        // App bundle is at: AppName.app
        if let appBundleURL = Bundle.main.bundleURL
            .deletingLastPathComponent() // PlugIns/
            .deletingLastPathComponent() // AppName.app/
            .appendingPathComponent("tr.lproj") as URL?,
           let appBundle = Bundle(url: appBundleURL) {
            let result = appBundle.localizedString(forKey: self, value: nil, table: nil)
            if result != self { return result }
        }
        
        return self
    }
    
    /// Returns the localized string with format arguments
    func localized(with arguments: CVarArg...) -> String {
        String(format: self.localized, arguments: arguments)
    }
}

