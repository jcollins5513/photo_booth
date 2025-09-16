import Foundation
import CoreData
import SwiftUI

// MARK: - VehiclePhoto Extensions

extension VehiclePhoto {
    /// Computed property for angle (maps to angleType)
    var angle: String {
        get { angleType ?? "" }
        set { angleType = newValue }
    }
    
    /// Computed property for timestamp (maps to captureDate)
    var timestamp: Date {
        get { captureDate ?? Date() }
        set { captureDate = newValue }
    }
    
    /// Computed property for session (already exists in Core Data model)
    // This is already defined in the Core Data model, so no need to add it
}

// MARK: - PhotoSession Extensions

extension PhotoSession {
    /// Computed property for timestamp (maps to startDate)
    var timestamp: Date {
        get { startDate ?? Date() }
        set { startDate = newValue }
    }
}

// MARK: - Session Status

enum SessionStatus: String, CaseIterable {
    case active = "active"
    case completed = "completed"
    case cancelled = "cancelled"
    case paused = "paused"
    
    var displayName: String {
        switch self {
        case .active: return "Active"
        case .completed: return "Completed"
        case .cancelled: return "Cancelled"
        case .paused: return "Paused"
        }
    }
    
    var color: Color {
        switch self {
        case .active: return .blue
        case .completed: return .green
        case .cancelled: return .red
        case .paused: return .orange
        }
    }
}
