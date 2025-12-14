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
        // Read Supabase config from Info.plist
        guard let supabaseURLString = Bundle.main.infoDictionary?["SUPABASE_URL"] as? String,
              let supabaseURL = URL(string: supabaseURLString),
              let supabaseKey = Bundle.main.infoDictionary?["SUPABASE_ANON_KEY"] as? String else {
            fatalError("❌ Missing SUPABASE_URL or SUPABASE_ANON_KEY in Info.plist")
        }
        
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
                #if DEBUG
                print("✅ Restored existing session: \(existingUserID)")
                #endif
                return
            }
            
            // Create new anonymous session
            let session = try await client.auth.signInAnonymously()
            let userID = session.user.id.uuidString
            
            currentUserID = userID
            isAuthenticated = true
            saveUserIDToKeychain(userID)
            
            #if DEBUG
            print("✅ Created anonymous session: \(userID)")
            #endif
        } catch {
            #if DEBUG
            print("❌ Failed to initialize anonymous session: \(error)")
            #endif
        }
    }
    
    func signOut() async {
        do {
            try await client.auth.signOut()
            clearLocalAuthData()
            #if DEBUG
            print("✅ Signed out successfully")
            #endif
        } catch {
            #if DEBUG
            print("❌ Failed to sign out: \(error)")
            #endif
            // Force local cleanup even if backend fails
            clearLocalAuthData()
        }
    }
    
    /// Delete account and all associated data (App Store required)
    func deleteAccount() async {
        guard let userID = currentUserID else {
            #if DEBUG
            print("❌ No user ID to delete")
            #endif
            clearLocalAuthData()
            return
        }
        
        do {
            // 1. Delete user data from Supabase tables
            // Delete bookmarks
            try await client
                .from("bookmarks")
                .delete()
                .eq("user_id", value: userID)
                .execute()
            
            // Delete collections
            try await client
                .from("collections")
                .delete()
                .eq("user_id", value: userID)
                .execute()
            
            // Delete routines
            try await client
                .from("routines")
                .delete()
                .eq("user_id", value: userID)
                .execute()
            
            // Delete sync actions
            try await client
                .from("sync_actions")
                .delete()
                .eq("user_id", value: userID)
                .execute()
            
            #if DEBUG
            print("✅ User data deleted from Supabase")
            #endif
            
            // 2. Sign out (this also deletes the anonymous user)
            try await client.auth.signOut()
            
            #if DEBUG
            print("✅ Account deleted successfully")
            #endif
        } catch {
            // Check if error is "table not found" (PGRST205) - this is expected if using offline-only
            let errorString = String(describing: error)
            if errorString.contains("PGRST205") {
                #if DEBUG
                print("⚠️ Supabase tables not found. Skipping remote data deletion.")
                #endif
            } else {
                #if DEBUG
                print("❌ Failed to delete account data: \(error)")
                #endif
            }
            // Even if backend fails, clean up local data
        }
        
        // 3. Always clear local data
        clearLocalAuthData()
    }
    
    private func clearLocalAuthData() {
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
            #if DEBUG
            print("✅ UserID saved to Keychain")
            #endif
        } else {
            #if DEBUG
            print("❌ Failed to save userID to Keychain: \(status)")
            #endif
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
            #if DEBUG
            print("❌ Failed to load userID from Keychain: \(status)")
            #endif
            return nil
        }
        
        return userID
    }
}
