//
//  Config.swift
//  jolt
//
//  Created by Onur Yurdusever on 5.12.2025.
//
//  Centralized configuration for API endpoints and keys.
//  Values are loaded from Info.plist.
//

import Foundation

enum Config {
    
    // MARK: - Supabase Configuration
    
    /// Supabase project URL
    static var supabaseURL: String {
        guard let url = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String else {
            fatalError("SUPABASE_URL not found in Info.plist")
        }
        return url
    }
    
    /// Supabase Edge Functions base URL
    static var supabaseFunctionsURL: String {
        return "\(supabaseURL)/functions/v1"
    }
    
    /// Supabase Anonymous Key
    static var supabaseAnonKey: String {
        guard let key = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY") as? String else {
            fatalError("SUPABASE_ANON_KEY not found in Info.plist")
        }
        return key
    }
    
    // MARK: - API Endpoints
    
    enum Endpoint {
        case parse
        
        var url: URL {
            switch self {
            case .parse:
                return URL(string: "\(Config.supabaseFunctionsURL)/parse")!
            }
        }
    }
    
    // MARK: - App Configuration
    
    /// Maximum concurrent network requests
    static let maxConcurrentRequests = 3
    
    /// Request timeout in seconds
    static let requestTimeout: TimeInterval = 30
}
