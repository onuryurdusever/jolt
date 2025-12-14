//
//  ShareLocalization.swift
//  JoltShareExtension
//
//  String localization utilities for Share Extension
//

import Foundation

// MARK: - String Extension for Share Extension

extension String {
    /// Returns the localized version of the string
    /// Share extensions run in their own process, so we need to explicitly load from the containing app's bundle
    var localized: String {
        // First try the extension's own bundle
        let extensionResult = NSLocalizedString(self, comment: "")
        if extensionResult != self { return extensionResult }
        
        // Fallback 1: Try extension's tr.lproj
        if let extensionPath = Bundle.main.path(forResource: "tr", ofType: "lproj"),
           let extensionBundle = Bundle(path: extensionPath) {
            let result = extensionBundle.localizedString(forKey: self, value: nil, table: nil)
            if result != self { return result }
        }
        
        // Fallback 2: Try to get the containing app's bundle
        // Share extension bundle is at: AppName.app/PlugIns/ShareExtension.appex
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
