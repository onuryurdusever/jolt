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
    var localized: String {
        NSLocalizedString(self, comment: "")
    }
    
    /// Returns the localized string with format arguments
    func localized(with arguments: CVarArg...) -> String {
        String(format: self.localized, arguments: arguments)
    }
}
