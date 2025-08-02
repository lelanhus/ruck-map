import Foundation
import SwiftData

// MARK: - Repository Protocol
protocol RuckSessionRepository: Sendable {
    func fetchAll() async throws -> [RuckSession]
    func fetch(by id: UUID) async throws -> RuckSession?
    func fetchActive() async throws -> RuckSession?
    func fetchRecent(limit: Int) async throws -> [RuckSession]
    func save(_ session: RuckSession) async throws
    func delete(_ session: RuckSession) async throws
    func deleteAll() async throws
}

// MARK: - SwiftData Implementation
@ModelActor
actor SwiftDataRuckSessionRepository: RuckSessionRepository {
    
    func fetchAll() async throws -> [RuckSession] {
        let descriptor = FetchDescriptor<RuckSession>(
            sortBy: [SortDescriptor(\.startDate, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }
    
    func fetch(by id: UUID) async throws -> RuckSession? {
        let descriptor = FetchDescriptor<RuckSession>(
            predicate: #Predicate { $0.id == id }
        )
        return try modelContext.fetch(descriptor).first
    }
    
    func fetchActive() async throws -> RuckSession? {
        let descriptor = FetchDescriptor<RuckSession>(
            predicate: #Predicate { $0.endDate == nil },
            sortBy: [SortDescriptor(\.startDate, order: .reverse)]
        )
        return try modelContext.fetch(descriptor).first
    }
    
    func fetchRecent(limit: Int = 50) async throws -> [RuckSession] {
        let descriptor = FetchDescriptor<RuckSession>(
            sortBy: [SortDescriptor(\.startDate, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        return try modelContext.fetch(descriptor)
    }
    
    func save(_ session: RuckSession) async throws {
        // Validate business rules
        if let activeSession = try await fetchActive(),
           activeSession.id != session.id {
            throw RuckSessionError.activeSessionExists
        }
        
        // Update modification timestamp
        session.updateModificationDate()
        
        modelContext.insert(session)
        try modelContext.save()
    }
    
    func delete(_ session: RuckSession) async throws {
        modelContext.delete(session)
        try modelContext.save()
    }
    
    func deleteAll() async throws {
        let sessions = try await fetchAll()
        for session in sessions {
            modelContext.delete(session)
        }
        try modelContext.save()
    }
}

// MARK: - Repository Errors
enum RuckSessionError: LocalizedError {
    case activeSessionExists
    case sessionNotFound
    case invalidData
    
    var errorDescription: String? {
        switch self {
        case .activeSessionExists:
            return "An active ruck session already exists. Please end the current session before starting a new one."
        case .sessionNotFound:
            return "The requested ruck session could not be found."
        case .invalidData:
            return "The session data is invalid."
        }
    }
}

// MARK: - Advanced Queries
extension SwiftDataRuckSessionRepository {
    
    func fetchSessions(
        after date: Date,
        before: Date? = nil,
        minDistance: Double? = nil,
        minWeight: Double? = nil
    ) async throws -> [RuckSession] {
        var predicates: [Predicate<RuckSession>] = [
            #Predicate { $0.startDate > date }
        ]
        
        if let before = before {
            predicates.append(#Predicate { $0.startDate < before })
        }
        
        if let minDistance = minDistance {
            predicates.append(#Predicate { $0.totalDistance >= minDistance })
        }
        
        if let minWeight = minWeight {
            predicates.append(#Predicate { $0.loadWeight >= minWeight })
        }
        
        let combinedPredicate = predicates.reduce(into: nil) { result, predicate in
            if let result = result {
                result = #Predicate { session in
                    predicate.evaluate(session) && result.evaluate(session)
                }
            } else {
                result = predicate
            }
        }
        
        let descriptor = FetchDescriptor<RuckSession>(
            predicate: combinedPredicate,
            sortBy: [SortDescriptor(\.startDate, order: .reverse)]
        )
        
        return try modelContext.fetch(descriptor)
    }
    
    func fetchStatistics(for period: StatsPeriod) async throws -> RuckSessionStats {
        let sessions = try await fetchSessions(after: period.startDate)
        
        return RuckSessionStats(
            totalSessions: sessions.count,
            totalDistance: sessions.reduce(0) { $0 + $1.totalDistance },
            totalDuration: sessions.reduce(0) { $0 + $1.totalDuration },
            totalCalories: sessions.reduce(0) { $0 + $1.totalCalories },
            averagePace: sessions.isEmpty ? 0 : sessions.reduce(0) { $0 + $1.averagePace } / Double(sessions.count),
            averageWeight: sessions.isEmpty ? 0 : sessions.reduce(0) { $0 + $1.loadWeight } / Double(sessions.count)
        )
    }
}

// MARK: - Supporting Types
enum StatsPeriod {
    case week
    case month
    case quarter
    case year
    
    var startDate: Date {
        let calendar = Calendar.current
        let now = Date()
        
        switch self {
        case .week:
            return calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now
        case .month:
            return calendar.dateInterval(of: .month, for: now)?.start ?? now
        case .quarter:
            let quarter = (calendar.component(.month, from: now) - 1) / 3
            let firstMonthOfQuarter = quarter * 3 + 1
            return calendar.date(from: DateComponents(
                year: calendar.component(.year, from: now),
                month: firstMonthOfQuarter,
                day: 1
            )) ?? now
        case .year:
            return calendar.dateInterval(of: .year, for: now)?.start ?? now
        }
    }
}

struct RuckSessionStats {
    let totalSessions: Int
    let totalDistance: Double
    let totalDuration: TimeInterval
    let totalCalories: Double
    let averagePace: Double
    let averageWeight: Double
    
    var averageDistance: Double {
        totalSessions > 0 ? totalDistance / Double(totalSessions) : 0
    }
    
    var averageDuration: TimeInterval {
        totalSessions > 0 ? totalDuration / Double(totalSessions) : 0
    }
    
    var averageCaloriesPerSession: Double {
        totalSessions > 0 ? totalCalories / Double(totalSessions) : 0
    }
}