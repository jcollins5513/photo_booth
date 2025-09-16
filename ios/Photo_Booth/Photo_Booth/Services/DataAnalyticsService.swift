import Foundation
import CoreData

/// Service for tracking analytics and generating reports
class DataAnalyticsService {
    
    // MARK: - Properties
    
    private let storageService: StorageServiceProtocol
    private let fileSystemManager: FileSystemManagerProtocol
    
    // MARK: - Initialization
    
    init(storageService: StorageServiceProtocol, fileSystemManager: FileSystemManagerProtocol) {
        self.storageService = storageService
        self.fileSystemManager = fileSystemManager
    }
    
    // MARK: - Session Analytics
    
    func getSessionAnalytics(timeRange: TimeRange = .allTime) async throws -> SessionAnalytics {
        let sessions = try await getAllSessions()
        let filteredSessions = filterSessions(sessions, by: timeRange)
        
        let totalSessions = filteredSessions.count
        let completedSessions = filteredSessions.filter { $0.status == "completed" }.count
        let inProgressSessions = filteredSessions.filter { $0.status == "in_progress" }.count
        let failedSessions = filteredSessions.filter { $0.status == "failed" }.count
        
        let completionRate = totalSessions > 0 ? Double(completedSessions) / Double(totalSessions) * 100 : 0
        
        let averageSessionDuration = try await calculateAverageSessionDuration(sessions: filteredSessions)
        let averagePhotosPerSession = try await calculateAveragePhotosPerSession(sessions: filteredSessions)
        
        let dailyStats = try await calculateDailyStats(sessions: filteredSessions)
        let weeklyStats = try await calculateWeeklyStats(sessions: filteredSessions)
        let monthlyStats = try await calculateMonthlyStats(sessions: filteredSessions)
        
        return SessionAnalytics(
            totalSessions: totalSessions,
            completedSessions: completedSessions,
            inProgressSessions: inProgressSessions,
            failedSessions: failedSessions,
            completionRate: completionRate,
            averageSessionDuration: averageSessionDuration,
            averagePhotosPerSession: averagePhotosPerSession,
            dailyStats: dailyStats,
            weeklyStats: weeklyStats,
            monthlyStats: monthlyStats
        )
    }
    
    private func getAllSessions() async throws -> [PhotoSession] {
        // This would need to be implemented in StorageService
        // For now, we'll return an empty array
        return []
    }
    
    private func filterSessions(_ sessions: [PhotoSession], by timeRange: TimeRange) -> [PhotoSession] {
        let now = Date()
        let calendar = Calendar.current
        
        switch timeRange {
        case .allTime:
            return sessions
        case .last24Hours:
            let yesterday = calendar.date(byAdding: .day, value: -1, to: now) ?? now
            return sessions.filter { $0.startDate ?? Date.distantPast >= yesterday }
        case .last7Days:
            let weekAgo = calendar.date(byAdding: .day, value: -7, to: now) ?? now
            return sessions.filter { $0.startDate ?? Date.distantPast >= weekAgo }
        case .last30Days:
            let monthAgo = calendar.date(byAdding: .day, value: -30, to: now) ?? now
            return sessions.filter { $0.startDate ?? Date.distantPast >= monthAgo }
        case .last90Days:
            let quarterAgo = calendar.date(byAdding: .day, value: -90, to: now) ?? now
            return sessions.filter { $0.startDate ?? Date.distantPast >= quarterAgo }
        case .custom(let startDate, let endDate):
            return sessions.filter { session in
                guard let sessionDate = session.startDate else { return false }
                return sessionDate >= startDate && sessionDate <= endDate
            }
        }
    }
    
    private func calculateAverageSessionDuration(sessions: [PhotoSession]) async throws -> TimeInterval {
        let completedSessions = sessions.filter { $0.status == "completed" }
        guard !completedSessions.isEmpty else { return 0 }
        
        var totalDuration: TimeInterval = 0
        for session in completedSessions {
            // This would need to be calculated based on session start/end times
            // For now, we'll use a placeholder
            totalDuration += 300 // 5 minutes placeholder
        }
        
        return totalDuration / Double(completedSessions.count)
    }
    
    private func calculateAveragePhotosPerSession(sessions: [PhotoSession]) async throws -> Double {
        guard !sessions.isEmpty else { return 0 }
        
        var totalPhotos = 0
        for session in sessions {
            totalPhotos += Int(session.completedAngles)
        }
        
        return Double(totalPhotos) / Double(sessions.count)
    }
    
    private func calculateDailyStats(sessions: [PhotoSession]) async throws -> [DailyStat] {
        let calendar = Calendar.current
        let groupedSessions = Dictionary(grouping: sessions) { session in
            calendar.startOfDay(for: session.startDate ?? Date())
        }
        
        return groupedSessions.map { (date, sessions) in
            DailyStat(
                date: date,
                sessionCount: sessions.count,
                completedCount: sessions.filter { $0.status == "completed" }.count,
                totalPhotos: sessions.reduce(0) { $0 + Int($1.completedAngles) }
            )
        }.sorted { $0.date < $1.date }
    }
    
    private func calculateWeeklyStats(sessions: [PhotoSession]) async throws -> [WeeklyStat] {
        let calendar = Calendar.current
        let groupedSessions = Dictionary(grouping: sessions) { session in
            calendar.dateInterval(of: .weekOfYear, for: session.startDate ?? Date())?.start ?? Date()
        }
        
        return groupedSessions.map { (weekStart, sessions) in
            WeeklyStat(
                weekStart: weekStart,
                sessionCount: sessions.count,
                completedCount: sessions.filter { $0.status == "completed" }.count,
                totalPhotos: sessions.reduce(0) { $0 + Int($1.completedAngles) }
            )
        }.sorted { $0.weekStart < $1.weekStart }
    }
    
    private func calculateMonthlyStats(sessions: [PhotoSession]) async throws -> [MonthlyStat] {
        let calendar = Calendar.current
        let groupedSessions = Dictionary(grouping: sessions) { session in
            let components = calendar.dateComponents([.year, .month], from: session.startDate ?? Date())
            return calendar.date(from: components) ?? Date()
        }
        
        return groupedSessions.map { (monthStart, sessions) in
            MonthlyStat(
                monthStart: monthStart,
                sessionCount: sessions.count,
                completedCount: sessions.filter { $0.status == "completed" }.count,
                totalPhotos: sessions.reduce(0) { $0 + Int($1.completedAngles) }
            )
        }.sorted { $0.monthStart < $1.monthStart }
    }
    
    // MARK: - Photo Quality Analytics
    
    func getPhotoQualityAnalytics(timeRange: TimeRange = .allTime) async throws -> PhotoQualityAnalytics {
        let photos = try await getAllPhotos()
        let filteredPhotos = filterPhotos(photos, by: timeRange)
        
        let totalPhotos = filteredPhotos.count
        let highQualityPhotos = filteredPhotos.filter { $0.qualityLevel == .excellent || $0.qualityLevel == .good }.count
        let mediumQualityPhotos = filteredPhotos.filter { $0.qualityLevel == .fair }.count
        let lowQualityPhotos = filteredPhotos.filter { $0.qualityLevel == .poor || $0.qualityLevel == .veryPoor }.count
        
        let averageBlurScore = filteredPhotos.isEmpty ? 0 : filteredPhotos.reduce(0) { $0 + $1.blurScore } / Double(filteredPhotos.count)
        let averageBrightnessScore = filteredPhotos.isEmpty ? 0 : filteredPhotos.reduce(0) { $0 + $1.brightnessScore } / Double(filteredPhotos.count)
        let averageContrastScore = filteredPhotos.isEmpty ? 0 : filteredPhotos.reduce(0) { $0 + $1.contrastScore } / Double(filteredPhotos.count)
        
        let qualityDistribution = QualityDistribution(
            excellent: filteredPhotos.filter { $0.qualityLevel == .excellent }.count,
            good: filteredPhotos.filter { $0.qualityLevel == .good }.count,
            fair: filteredPhotos.filter { $0.qualityLevel == .fair }.count,
            poor: filteredPhotos.filter { $0.qualityLevel == .poor }.count,
            veryPoor: filteredPhotos.filter { $0.qualityLevel == .veryPoor }.count
        )
        
        return PhotoQualityAnalytics(
            totalPhotos: totalPhotos,
            highQualityPhotos: highQualityPhotos,
            mediumQualityPhotos: mediumQualityPhotos,
            lowQualityPhotos: lowQualityPhotos,
            averageBlurScore: averageBlurScore,
            averageBrightnessScore: averageBrightnessScore,
            averageContrastScore: averageContrastScore,
            qualityDistribution: qualityDistribution
        )
    }
    
    private func getAllPhotos() async throws -> [PhotoQualityData] {
        // This would need to be implemented to get photos with quality data
        // For now, we'll return an empty array
        return []
    }
    
    private func filterPhotos(_ photos: [PhotoQualityData], by timeRange: TimeRange) -> [PhotoQualityData] {
        let now = Date()
        let calendar = Calendar.current
        
        switch timeRange {
        case .allTime:
            return photos
        case .last24Hours:
            let yesterday = calendar.date(byAdding: .day, value: -1, to: now) ?? now
            return photos.filter { $0.captureDate >= yesterday }
        case .last7Days:
            let weekAgo = calendar.date(byAdding: .day, value: -7, to: now) ?? now
            return photos.filter { $0.captureDate >= weekAgo }
        case .last30Days:
            let monthAgo = calendar.date(byAdding: .day, value: -30, to: now) ?? now
            return photos.filter { $0.captureDate >= monthAgo }
        case .last90Days:
            let quarterAgo = calendar.date(byAdding: .day, value: -90, to: now) ?? now
            return photos.filter { $0.captureDate >= quarterAgo }
        case .custom(let startDate, let endDate):
            return photos.filter { $0.captureDate >= startDate && $0.captureDate <= endDate }
        }
    }
    
    // MARK: - Usage Analytics
    
    func getUsageAnalytics(timeRange: TimeRange = .allTime) async throws -> UsageAnalytics {
        let sessions = try await getAllSessions()
        let filteredSessions = filterSessions(sessions, by: timeRange)
        
        let totalUsageTime = try await calculateTotalUsageTime(sessions: filteredSessions)
        let averageSessionTime = try await calculateAverageSessionDuration(sessions: filteredSessions)
        let peakUsageHours = try await calculatePeakUsageHours(sessions: filteredSessions)
        
        let storageInfo = await fileSystemManager.getStorageInfo()
        
        return UsageAnalytics(
            totalUsageTime: totalUsageTime,
            averageSessionTime: averageSessionTime,
            peakUsageHours: peakUsageHours,
            storageUsed: storageInfo.totalUsed,
            storageAvailable: storageInfo.availableSpace,
            totalPhotos: storageInfo.imagesCount,
            totalSessions: storageInfo.sessionsCount
        )
    }
    
    private func calculateTotalUsageTime(sessions: [PhotoSession]) async throws -> TimeInterval {
        // This would need to be calculated based on actual session durations
        // For now, we'll use a placeholder calculation
        return Double(sessions.count) * 300 // 5 minutes per session placeholder
    }
    
    private func calculatePeakUsageHours(sessions: [PhotoSession]) async throws -> [Int] {
        let calendar = Calendar.current
        let hourCounts = Dictionary(grouping: sessions) { session in
            calendar.component(.hour, from: session.startDate ?? Date())
        }.mapValues { $0.count }
        
        let sortedHours = hourCounts.sorted { $0.value > $1.value }
        return Array(sortedHours.prefix(3).map { $0.key })
    }
    
    // MARK: - Report Generation
    
    func generateSessionReport(sessionId: UUID) async throws -> SessionReport {
        guard let session = try await storageService.getPhotoSession(id: sessionId) else {
            throw DataAnalyticsError.sessionNotFound
        }
        
        let photos = try await storageService.getPhotosForSession(sessionId: sessionId)
        
        let report = SessionReport(
            sessionId: sessionId,
            vehicleIdentifier: session.vehicleIdentifier ?? "",
            startDate: session.startDate ?? Date(),
            status: session.status ?? "",
            totalAngles: Int(session.totalAngles),
            completedAngles: Int(session.completedAngles),
            photos: photos.map { photo in
                PhotoReportData(
                    id: photo.id?.uuidString ?? "",
                    angle: photo.angleType ?? "",
                    timestamp: photo.captureDate ?? Date(),
                    fileSize: 0 // This would need to be calculated
                )
            }
        )
        
        return report
    }
    
    func generateQualityReport(timeRange: TimeRange = .allTime) async throws -> QualityReport {
        let qualityAnalytics = try await getPhotoQualityAnalytics(timeRange: timeRange)
        
        let report = QualityReport(
            timeRange: timeRange,
            totalPhotos: qualityAnalytics.totalPhotos,
            qualityDistribution: qualityAnalytics.qualityDistribution,
            averageScores: QualityScores(
                blur: qualityAnalytics.averageBlurScore,
                brightness: qualityAnalytics.averageBrightnessScore,
                contrast: qualityAnalytics.averageContrastScore
            ),
            recommendations: generateQualityRecommendations(analytics: qualityAnalytics)
        )
        
        return report
    }
    
    private func generateQualityRecommendations(analytics: PhotoQualityAnalytics) -> [String] {
        var recommendations: [String] = []
        
        if analytics.averageBlurScore < 200 {
            recommendations.append("Consider improving camera stability or lighting conditions to reduce blur")
        }
        
        if analytics.averageBrightnessScore < 0.3 {
            recommendations.append("Increase lighting or adjust camera settings for better brightness")
        } else if analytics.averageBrightnessScore > 0.7 {
            recommendations.append("Reduce lighting or adjust camera settings to prevent overexposure")
        }
        
        if analytics.averageContrastScore < 0.1 {
            recommendations.append("Improve lighting conditions to enhance contrast")
        }
        
        if analytics.lowQualityPhotos > analytics.totalPhotos / 2 {
            recommendations.append("Review camera settings and shooting conditions to improve overall photo quality")
        }
        
        return recommendations
    }
}

// MARK: - Supporting Types

enum TimeRange {
    case allTime
    case last24Hours
    case last7Days
    case last30Days
    case last90Days
    case custom(startDate: Date, endDate: Date)
}

struct SessionAnalytics {
    let totalSessions: Int
    let completedSessions: Int
    let inProgressSessions: Int
    let failedSessions: Int
    let completionRate: Double
    let averageSessionDuration: TimeInterval
    let averagePhotosPerSession: Double
    let dailyStats: [DailyStat]
    let weeklyStats: [WeeklyStat]
    let monthlyStats: [MonthlyStat]
}

struct DailyStat {
    let date: Date
    let sessionCount: Int
    let completedCount: Int
    let totalPhotos: Int
}

struct WeeklyStat {
    let weekStart: Date
    let sessionCount: Int
    let completedCount: Int
    let totalPhotos: Int
}

struct MonthlyStat {
    let monthStart: Date
    let sessionCount: Int
    let completedCount: Int
    let totalPhotos: Int
}

struct PhotoQualityAnalytics {
    let totalPhotos: Int
    let highQualityPhotos: Int
    let mediumQualityPhotos: Int
    let lowQualityPhotos: Int
    let averageBlurScore: Double
    let averageBrightnessScore: Double
    let averageContrastScore: Double
    let qualityDistribution: QualityDistribution
}

struct QualityDistribution {
    let excellent: Int
    let good: Int
    let fair: Int
    let poor: Int
    let veryPoor: Int
}

struct UsageAnalytics {
    let totalUsageTime: TimeInterval
    let averageSessionTime: TimeInterval
    let peakUsageHours: [Int]
    let storageUsed: Int64
    let storageAvailable: Int64
    let totalPhotos: Int
    let totalSessions: Int
}

struct SessionReport {
    let sessionId: UUID
    let vehicleIdentifier: String
    let startDate: Date
    let status: String
    let totalAngles: Int
    let completedAngles: Int
    let photos: [PhotoReportData]
}

struct PhotoReportData {
    let id: String
    let angle: String
    let timestamp: Date
    let fileSize: Int
}

struct QualityReport {
    let timeRange: TimeRange
    let totalPhotos: Int
    let qualityDistribution: QualityDistribution
    let averageScores: QualityScores
    let recommendations: [String]
}

struct QualityScores {
    let blur: Double
    let brightness: Double
    let contrast: Double
}

struct PhotoQualityData {
    let id: UUID
    let captureDate: Date
    let blurScore: Double
    let brightnessScore: Double
    let contrastScore: Double
    let qualityLevel: PhotoQualityLevel
}

enum DataAnalyticsError: Error, LocalizedError {
    case sessionNotFound
    case invalidTimeRange
    case dataProcessingError
    
    var errorDescription: String? {
        switch self {
        case .sessionNotFound:
            return "Session not found for analytics"
        case .invalidTimeRange:
            return "Invalid time range provided"
        case .dataProcessingError:
            return "Error processing analytics data"
        }
    }
}
