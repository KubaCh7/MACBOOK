import Foundation
import SwiftData

/// Cel zapisany lokalnie (działa offline). Synchronizowany z tabelą `goals`.
@Model
final class GoalEntity {
    @Attribute(.unique) var id: UUID
    var name: String
    var targetAmount: Double
    /// ścieżka w Storage (<user_id>/<goal_id>.jpg) albo link https://
    var photoURL: String?
    var photoPosition: String
    @Attribute(.externalStorage) var photoData: Data?
    var catalogID: String?
    var isDefault: Bool
    var createdAt: Date
    var updatedAt: Date
    var deletedAt: Date?
    var needsSync: Bool
    var photoNeedsUpload: Bool

    init(id: UUID = UUID(), name: String, targetAmount: Double, catalogID: String? = nil, isDefault: Bool = false) {
        self.id = id
        self.name = name
        self.targetAmount = targetAmount
        self.photoURL = nil
        self.photoPosition = "50% 50%"
        self.photoData = nil
        self.catalogID = catalogID
        self.isDefault = isDefault
        self.createdAt = Date()
        self.updatedAt = Date()
        self.deletedAt = nil
        self.needsSync = true
        self.photoNeedsUpload = false
    }
}

/// Wpłata (+) lub wypłata (−). Synchronizowana z tabelą `deposits`.
@Model
final class DepositEntity {
    @Attribute(.unique) var id: UUID
    var goalID: UUID
    var amount: Double
    /// data w formacie YYYY-MM-DD (bez strefy czasowej)
    var day: String
    var note: String?
    var createdAt: Date
    var updatedAt: Date
    var deletedAt: Date?
    var needsSync: Bool

    init(id: UUID = UUID(), goalID: UUID, amount: Double, day: String, note: String?) {
        self.id = id
        self.goalID = goalID
        self.amount = amount
        self.day = day
        self.note = note
        self.createdAt = Date()
        self.updatedAt = Date()
        self.deletedAt = nil
        self.needsSync = true
    }
}
