import Foundation
import FirebaseFirestore

struct Comment: Identifiable, Codable, Equatable {
    @DocumentID var id: String?
    var text: String
    var createdBy: String
    var createdByUsername: String?
    var createdAt: Date
    
    init(id: String? = nil, text: String, createdBy: String, createdByUsername: String? = nil, createdAt: Date = Date()) {
        self.id = id
        self.text = text
        self.createdBy = createdBy
        self.createdByUsername = createdByUsername
        self.createdAt = createdAt
    }
}