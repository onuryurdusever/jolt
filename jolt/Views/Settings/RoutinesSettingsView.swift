import SwiftUI
import SwiftData

struct RoutinesSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Routine.hour) private var routines: [Routine]
    @State private var showAddRoutine = false
    @State private var editingRoutine: Routine?
    
    var body: some View {
        List {
            Section {
                if routines.isEmpty {
                    Text("routinesSettings.empty".localized)
                        .foregroundColor(.gray)
                } else {
                    ForEach(routines) { routine in
                        Button {
                            editingRoutine = routine
                        } label: {
                            RoutineRow(routine: routine)
                        }
                    }
                    .onDelete(perform: deleteRoutine)
                }
            } header: {
                Text("routinesSettings.title".localized)
            } footer: {
                Text("routinesSettings.subtitle".localized)
            }
        }
        .navigationTitle("routines.title".localized)
        .toolbar {
            Button {
                showAddRoutine = true
            } label: {
                Image(systemName: "plus")
            }
        }
        .sheet(isPresented: $showAddRoutine) {
            EditRoutineView(routine: nil)
        }
        .sheet(item: $editingRoutine) { routine in
            EditRoutineView(routine: routine)
        }
        .onAppear {
            if routines.isEmpty {
                initDefaultRoutines()
            }
        }
    }
    
    private func deleteRoutine(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(routines[index])
        }
    }
    
    private func initDefaultRoutines() {
        let defaults = Routine.defaultRoutines()
        for routine in defaults {
            modelContext.insert(routine)
        }
    }
}

struct RoutineRow: View {
    let routine: Routine
    
    var body: some View {
        HStack {
            Image(systemName: routine.icon)
                .font(.title2)
                .foregroundColor(.joltYellow)
                .frame(width: 40)
            
            VStack(alignment: .leading) {
                Text(routine.name)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(routine.timeString)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if !routine.isEnabled {
                Text("routinesSettings.off".localized)
                    .font(.caption)
                    .foregroundColor(.gray)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(4)
            }
        }
        .padding(.vertical, 4)
    }
}

struct EditRoutineView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    var routine: Routine?
    
    @State private var name = ""
    @State private var date = Date()
    @State private var selectedIcon = "clock.fill"
    @State private var isEnabled = true
    @State private var selectedDays: Set<Int> = [1, 2, 3, 4, 5, 6, 7]
    
    let icons = ["sun.max.fill", "moon.fill", "cup.and.saucer.fill", "briefcase.fill", "house.fill", "figure.run", "book.fill", "calendar"]
    
    init(routine: Routine?) {
        self.routine = routine
        _name = State(initialValue: routine?.name ?? "")
        _selectedIcon = State(initialValue: routine?.icon ?? "clock.fill")
        _isEnabled = State(initialValue: routine?.isEnabled ?? true)
        
        if let routine = routine {
            var components = DateComponents()
            components.hour = routine.hour
            components.minute = routine.minute
            _date = State(initialValue: Calendar.current.date(from: components) ?? Date())
            _selectedDays = State(initialValue: Set(routine.days))
        } else {
            // Default to 9:00 AM for new
            var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
            components.hour = 9
            components.minute = 0
            _date = State(initialValue: Calendar.current.date(from: components) ?? Date())
        }
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("routines.details".localized) {
                    TextField("routines.name".localized, text: $name)
                    DatePicker("routines.time".localized, selection: $date, displayedComponents: .hourAndMinute)
                    Toggle("routines.enabled".localized, isOn: $isEnabled)
                }
                
                Section("routines.icon".localized) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(icons, id: \.self) { icon in
                                Image(systemName: icon)
                                    .font(.title2)
                                    .padding(12)
                                    .background(selectedIcon == icon ? Color.joltYellow.opacity(0.2) : Color.gray.opacity(0.1))
                                    .foregroundColor(selectedIcon == icon ? .joltYellow : .primary)
                                    .cornerRadius(12)
                                    .onTapGesture {
                                        selectedIcon = icon
                                    }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                
                Section("routines.days".localized) {
                    HStack {
                        ForEach(1...7, id: \.self) { day in
                            DayButton(day: day, isSelected: selectedDays.contains(day)) {
                                if selectedDays.contains(day) {
                                    selectedDays.remove(day)
                                } else {
                                    selectedDays.insert(day)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle(routine == nil ? "routines.addRoutine".localized : "routines.editRoutine".localized)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel".localized) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("common.save".localized) {
                        save()
                    }
                    .disabled(name.isEmpty || selectedDays.isEmpty)
                }
            }
        }
    }
    
    private func save() {
        let calendar = Calendar.current
        let newHour = calendar.component(.hour, from: date)
        let newMinute = calendar.component(.minute, from: date)
        
        if let routine = routine {
            // Capture old time for cascade update
            let oldHour = routine.hour
            let oldMinute = routine.minute
            
            // Update Routine
            routine.name = name
            routine.icon = selectedIcon
            routine.hour = newHour
            routine.minute = newMinute
            routine.days = Array(selectedDays).sorted()
            routine.isEnabled = isEnabled
            
            // Cascade Update: Move pending bookmarks to new time
            if oldHour != newHour || oldMinute != newMinute {
                updatePendingBookmarks(from: oldHour, oldMinute: oldMinute, to: newHour, newMinute: newMinute)
            }
        } else {
            let newRoutine = Routine(
                name: name,
                icon: selectedIcon,
                hour: newHour,
                minute: newMinute,
                days: Array(selectedDays).sorted(),
                isEnabled: isEnabled
            )
            modelContext.insert(newRoutine)
        }
        
        try? modelContext.save()
        
        // Refresh Smart Notifications
        NotificationManager.shared.scheduleSmartNotifications(modelContext: modelContext)
        
        dismiss()
    }
    
    private func updatePendingBookmarks(from oldHour: Int, oldMinute: Int, to newHour: Int, newMinute: Int) {
        // Heuristic: Find pending bookmarks scheduled for the old time slot
        // We can't filter by hour/minute directly in Predicate easily with Date, 
        // so we fetch pending ones and filter in memory or use a broader range if possible.
        // For now, fetching all pending is safe as the list shouldn't be huge.
        
        let pendingStatus = BookmarkStatus.pending
        let descriptor = FetchDescriptor<Bookmark>(
            predicate: #Predicate<Bookmark> { bookmark in
                bookmark.status == pendingStatus
            }
        )
        
        if let bookmarks = try? modelContext.fetch(descriptor) {
            let calendar = Calendar.current
            var updateCount = 0
            
            for bookmark in bookmarks {
                let bHour = calendar.component(.hour, from: bookmark.scheduledFor)
                let bMinute = calendar.component(.minute, from: bookmark.scheduledFor)
                
                if bHour == oldHour && bMinute == oldMinute {
                    // Move to new time, keeping the same day
                    if let newDate = calendar.date(bySettingHour: newHour, minute: newMinute, second: 0, of: bookmark.scheduledFor) {
                        bookmark.scheduledFor = newDate
                        updateCount += 1
                    }
                }
            }
            print("🔄 Cascaded routine update to \(updateCount) bookmarks")
        }
    }
}

struct DayButton: View {
    let day: Int
    let isSelected: Bool
    let action: () -> Void
    
    var label: String {
        let formatter = DateFormatter()
        return formatter.shortWeekdaySymbols[day - 1].prefix(1).uppercased()
    }
    
    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.caption)
                .fontWeight(.bold)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(isSelected ? Color.joltYellow : Color.gray.opacity(0.1))
                .foregroundColor(isSelected ? .black : .primary)
                .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}
