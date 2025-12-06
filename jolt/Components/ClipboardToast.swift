//
//  ClipboardToast.swift
//  jolt
//
//  Created by Onur Yurdusever on 1.12.2025.
//

import SwiftUI

import SwiftUI

enum ClipboardToastType {
    case new
    case existingUnread // Focus/Inbox
    case existingArchived // Library
    case error // Invalid content
    case undo // Undo Jolt action
}

struct ClipboardToast: View {
    let url: String
    let type: ClipboardToastType
    let onAction: () -> Void
    let onDismiss: () -> Void
    
    private var displayDomain: String {
        if type == .error {
            return "clipboard.error.invalidContent".localized
        }
        if let url = URL(string: url),
           let host = url.host() {
            return host.replacingOccurrences(of: "www.", with: "")
        }
        return "URL"
    }
    
    private var title: String {
        switch type {
        case .new:
            return "clipboard.linkDetected".localized
        case .existingUnread:
            return "clipboard.alreadyInList".localized
        case .existingArchived:
            return "clipboard.alreadyRead".localized
        case .error:
            return "clipboard.invalidContent".localized
        case .undo:
            return "clipboard.jolted".localized
        }
    }
    
    private var buttonTitle: String {
        switch type {
        case .new:
            return "clipboard.action.jolt".localized
        case .existingUnread:
            return "clipboard.action.show".localized
        case .existingArchived:
            return "clipboard.action.rejolt".localized
        case .error:
            return "common.ok".localized
        case .undo:
            return "clipboard.action.undo".localized
        }
    }
    
    private var buttonIcon: String {
        switch type {
        case .new:
            return "bolt.fill"
        case .existingUnread:
            return "arrow.up.forward"
        case .existingArchived:
            return "arrow.clockwise"
        case .error:
            return "checkmark"
        case .undo:
            return "arrow.uturn.backward"
        }
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: type == .undo ? "checkmark.circle.fill" : "doc.on.clipboard.fill")
                .font(.system(size: 20))
                .foregroundColor(Color(hex: "#CCFF00"))
            
            // Text
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                
                Text(displayDomain)
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
            
            // Action Button
            Button(action: {
                let generator = UIImpactFeedbackGenerator(style: .medium)
                generator.impactOccurred()
                onAction()
            }) {
                HStack(spacing: 6) {
                    Text(buttonTitle)
                        .font(.system(size: 14, weight: .bold))
                    
                    Image(systemName: buttonIcon)
                        .font(.system(size: 14, weight: .bold))
                }
                .foregroundColor(.black)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color(hex: "#CCFF00"))
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            
            // Dismiss
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.gray)
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(Color.joltCardBackground)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.3), radius: 12, x: 0, y: 4)
        .padding(.horizontal, 20)
        .onAppear {
            let generator = UIImpactFeedbackGenerator(style: .soft)
            generator.impactOccurred()
        }
    }
}

// MARK: - Toast Modifier

struct ClipboardToastModifier: ViewModifier {
    @Binding var isPresented: Bool
    let url: String
    let type: ClipboardToastType
    let onAction: () -> Void
    
    func body(content: Content) -> some View {
        ZStack(alignment: .bottom) {
            content
            
            if isPresented {
                VStack {
                    Spacer()
                    
                    ClipboardToast(
                        url: url,
                        type: type,
                        onAction: onAction,
                        onDismiss: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                isPresented = false
                            }
                        }
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .padding(.bottom, 20)
                }
                .zIndex(999)
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isPresented)
    }
}

extension View {
    func clipboardToast(
        isPresented: Binding<Bool>,
        url: String,
        type: ClipboardToastType = .new,
        onAction: @escaping () -> Void
    ) -> some View {
        modifier(ClipboardToastModifier(
            isPresented: isPresented,
            url: url,
            type: type,
            onAction: onAction
        ))
    }
}

#Preview {
    ZStack {
        Color.joltBackground.ignoresSafeArea()
        
        VStack {
            ClipboardToast(
                url: "https://medium.com/example-article",
                type: .new,
                onAction: {},
                onDismiss: {}
            )
            
            Spacer()
        }
        .padding(.top, 60)
    }
}
