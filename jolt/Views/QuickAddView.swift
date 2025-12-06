//
//  QuickAddView.swift
//  jolt
//
//  Thin wrapper for QuickCaptureView - used in main app
//  Created by Onur Yurdusever on 2.12.2025.
//

import SwiftUI
import SwiftData

struct QuickAddView: View {
    let url: String
    let modelContext: ModelContext
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        QuickCaptureView(
            url: url,
            source: .clipboard,
            onComplete: { result in
                dismiss()
            },
            modelContext: modelContext
        )
    }
}
