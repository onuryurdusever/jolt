import Foundation
import SwiftData

@Model
final class Routine {
    @Attribute(.unique) var id: UUID
    var name: String
    var icon: String
    var hour: Int
    var minute: Int
    var days: [Int] // 1 = Sunday, 2 = Monday, ... 7 = Saturday (Calendar compatible)
    var isEnabled: Bool
    var createdAt: Date
    
    init(
        id: UUID = UUID(),
        name: String,
        icon: String,
        hour: Int,
        minute: Int,
        days: [Int] = [1, 2, 3, 4, 5, 6, 7], // Default daily
        isEnabled: Bool = true,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.icon = icon
        self.hour = hour
        self.minute = minute
        self.days = days
        self.isEnabled = isEnabled
        self.createdAt = createdAt
    }
    
    var timeString: String {
        String(format: "%02d:%02d", hour, minute)
    }
    
    static func defaultRoutines() -> [Routine] {
        return [
            Routine(name: "Start My Day", icon: "sun.max.fill", hour: 9, minute: 0, days: [2, 3, 4, 5, 6]), // Mon-Fri
            Routine(name: "Wind Down", icon: "moon.fill", hour: 21, minute: 0, days: [1, 2, 3, 4, 5, 6, 7]), // Daily
            Routine(name: "Weekend Catch-up", icon: "calendar", hour: 11, minute: 0, days: [1, 7]) // Sun, Sat
        ]
    }
}
