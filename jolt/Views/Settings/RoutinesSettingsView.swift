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
                    Text("deliverySettings.empty".localized)
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
                Text("deliverySettings.title".localized)
            } footer: {
                Text("deliverySettings.subtitle".localized)
            }
        }
        .navigationTitle("delivery.title".localized)
        .toolbar {
            Button {
                showAddRoutine = true
            } label: {
                Image(systemName: "plus")
            }
        }
        .sheet(isPresented: $showAddRoutine) {
            EditRoutineView(routine: nil)
                .presentationDetents([.large])
        }
        .sheet(item: $editingRoutine) { routine in
            EditRoutineView(routine: routine)
                .id(routine.id) // Force view recreation for each routine
                .presentationDetents([.large])
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
        
        // Post notification for centralized scheduling
        NotificationCenter.default.post(name: .routinesDidChange, object: nil)
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
                Text("deliverySettings.off".localized)
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
    
    let routine: Routine?
    
    @State private var name: String
    @State private var date: Date
    @State private var selectedIcon: String
    @State private var isEnabled: Bool
    @State private var selectedDays: Set<Int>
    
    let icons = ["sun.max.fill", "moon.fill", "cup.and.saucer.fill", "briefcase.fill", "house.fill", "figure.run", "book.fill", "calendar"]
    
    init(routine: Routine?) {
        self.routine = routine
        
        if let routine = routine {
            _name = State(initialValue: routine.name)
            _selectedIcon = State(initialValue: routine.icon)
            _isEnabled = State(initialValue: routine.isEnabled)
            _selectedDays = State(initialValue: Set(routine.days))
            
            var components = DateComponents()
            components.hour = routine.hour
            components.minute = routine.minute
            let routineDate = Calendar.current.date(from: components) ?? Date()
            _date = State(initialValue: routineDate)
        } else {
            // Default values for new routine
            _name = State(initialValue: "")
            _selectedIcon = State(initialValue: "clock.fill")
            _isEnabled = State(initialValue: true)
            _selectedDays = State(initialValue: [1, 2, 3, 4, 5, 6, 7])
            
            var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
            components.hour = 9
            components.minute = 0
            let defaultDate = Calendar.current.date(from: components) ?? Date()
            _date = State(initialValue: defaultDate)
        }
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("delivery.details".localized) {
                    TextField("delivery.name".localized, text: $name)
                    DatePicker("delivery.time".localized, selection: $date, displayedComponents: .hourAndMinute)
                    Toggle("delivery.enabled".localized, isOn: $isEnabled)
                }
                
                Section("delivery.icon".localized) {
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
                
                Section("delivery.days".localized) {
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
            .navigationTitle(routine == nil ? "delivery.addDelivery".localized : "delivery.editDelivery".localized)
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
        
        // Post notification for centralized scheduling
        NotificationCenter.default.post(name: .routinesDidChange, object: nil)
        
        dismiss()
    }
    
    private func updatePendingBookmarks(from oldHour: Int, oldMinute: Int, to newHour: Int, newMinute: Int) {
        // Heuristic: Find active bookmarks scheduled for the old time slot
        // We can't filter by hour/minute directly in Predicate easily with Date, 
        // so we fetch active ones and filter in memory or use a broader range if possible.
        // For now, fetching all active is safe as the list shouldn't be huge.
        
        let activeStatus = BookmarkStatus.active
        let descriptor = FetchDescriptor<Bookmark>(
            predicate: #Predicate<Bookmark> { bookmark in
                bookmark.status == activeStatus
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
