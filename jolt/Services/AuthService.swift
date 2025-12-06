//
//  AuthService.swift
//  jolt
//
//  Created by Onur Yurdusever on 1.12.2025.
//

import Foundation
import Supabase
import Combine

@MainActor
class AuthService: ObservableObject {
    static let shared = AuthService()
    
    @Published var currentUserID: String?
    @Published var isAuthenticated = false
    
    private let client: SupabaseClient
    private let userIDKey = "jolt.userId"
    
    private init() {
        // TODO: Replace with your Supabase URL and anon key
        let supabaseURL = URL(string: "https://tksukbumdgogpvhdzajq.supabase.co")!
        let supabaseKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRrc3VrYnVtZGdvZ3B2aGR6YWpxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjQ1ODkzMDIsImV4cCI6MjA4MDE2NTMwMn0.wWgyTSFtOyIie0E6050qEwvJRBVBcS4OamNOQoyj6aU"
        
        self.client = SupabaseClient(
            supabaseURL: supabaseURL,
            supabaseKey: supabaseKey
        )
        
        loadSession()
    }
    
    func initializeAnonymousSession() async {
        do {
            // Check if we already have a session
            if let existingUserID = loadUserIDFromKeychain() {
                currentUserID = existingUserID
                isAuthenticated = true
                print("✅ Restored existing session: \(existingUserID)")
                return
            }
            
            // Create new anonymous session
            let session = try await client.auth.signInAnonymously()
            let userID = session.user.id.uuidString
            
            currentUserID = userID
            isAuthenticated = true
            saveUserIDToKeychain(userID)
            
            print("✅ Created anonymous session: \(userID)")
        } catch {
            print("❌ Failed to initialize anonymous session: \(error)")
        }
    }
    
    func signOut() async {
        do {
            try await client.auth.signOut()
            
            // Clear Keychain
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrAccount as String: userIDKey,
                kSecAttrAccessGroup as String: "group.com.jolt.shared"
            ]
            SecItemDelete(query as CFDictionary)
            
            // Reset State
            currentUserID = nil
            isAuthenticated = false
            
            print("✅ Signed out successfully")
        } catch {
            print("❌ Failed to sign out: \(error)")
            
            // Force local cleanup even if backend fails
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrAccount as String: userIDKey,
                kSecAttrAccessGroup as String: "group.com.jolt.shared"
            ]
            SecItemDelete(query as CFDictionary)
            currentUserID = nil
            isAuthenticated = false
        }
    }
    
    private func loadSession() {
        if let userID = loadUserIDFromKeychain() {
            currentUserID = userID
            isAuthenticated = true
        }
    }
    
    // MARK: - Keychain Storage
    
    private func saveUserIDToKeychain(_ userID: String) {
        let data = userID.data(using: .utf8)!
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: userIDKey,
            kSecAttrAccessGroup as String: "group.com.jolt.shared", // Share with extension
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
        
        // Delete any existing item
        SecItemDelete(query as CFDictionary)
        
        // Add new item
        let status = SecItemAdd(query as CFDictionary, nil)
        if status == errSecSuccess {
            print("✅ UserID saved to Keychain")
        } else {
            print("❌ Failed to save userID to Keychain: \(status)")
        }
    }
    
    private func loadUserIDFromKeychain() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: userIDKey,
            kSecAttrAccessGroup as String: "group.com.jolt.shared", // Share with extension
            kSecReturnData as String: true
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let data = result as? Data,
              let userID = String(data: data, encoding: .utf8) else {
            print("❌ Failed to load userID from Keychain: \(status)")
            return nil
        }
        
        return userID
    }
}
