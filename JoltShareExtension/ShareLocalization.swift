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
    var localized: String {
        NSLocalizedString(self, comment: "")
    }
    
    /// Returns the localized string with format arguments
    func localized(with arguments: CVarArg...) -> String {
        String(format: self.localized, arguments: arguments)
    }
}
