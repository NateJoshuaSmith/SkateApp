import Foundation
import FirebaseFirestore

struct UserProfile: Codable {
    @DocumentID var id: String?  // User's Firebase Auth UID
    var username: String
    var email: String
    var createdAt: Date
    
    init(id: String? = nil, username: String, email: String, createdAt: Date = Date()) {
        self.id = id
        self.username = username
        self.email = email
        self.createdAt = createdAt
    }
}