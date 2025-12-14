//
//  ActionRequestHandler.swift
//  JoltActionExtension
//
//  Handler for Action Extension requests
//

import UIKit
import MobileCoreServices
import UniformTypeIdentifiers

class ActionRequestHandler: NSObject, NSExtensionRequestHandling {
    
    var extensionContext: NSExtensionContext?
    
    func beginRequest(with context: NSExtensionContext) {
        self.extensionContext = context
        
        // Redirect to ActionViewController logic
        // This handler is not used when we have a view controller
        context.completeRequest(returningItems: nil, completionHandler: nil)
    }
}
