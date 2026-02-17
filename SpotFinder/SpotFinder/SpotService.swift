//
//  SpotService.swift
//  SpotFinder
//
//  Created by Nathan Smith on 11/20/25.
//

import Foundation
import Combine
import FirebaseFirestore
import FirebaseAuth

class SpotService: ObservableObject {
    private let db = Firestore.firestore()
    private let collectionName = "skateSpots"
    
    @Published var spots: [SkateSpot] = []
    
    // Fetch all spots
    func fetchSpots() async {
        do {
            let snapshot = try await db.collection(collectionName)
                .order(by: "createdAt", descending: true)
                .getDocuments()
            
            spots = snapshot.documents.compactMap { document in
                try? document.data(as: SkateSpot.self)
            }
        } catch {
            print("Error fetching spots: \(error)")
        }
    }

    // Get username for current user (from Firestore or create default)
    private func getCurrentUsername() async -> String {
        guard let currentUser = Auth.auth().currentUser,
            let email = currentUser.email else {
            return "Anonymous"
        }
        
        let userId = currentUser.uid
        
        do {
            // Try to fetch user profile from Firestore
            let doc = try await db.collection("users").document(userId).getDocument()
            
            if doc.exists, let profile = try? doc.data(as: UserProfile.self) {
                return profile.username  // Return stored username
            } else {
                // User doesn't have a profile yet, create one with email prefix
                let defaultUsername = email.components(separatedBy: "@").first ?? "User"
                let profile = UserProfile(
                    id: userId,
                    username: defaultUsername,
                    email: email
                )
                try db.collection("users").document(userId).setData(from: profile)
                return defaultUsername
            }
        } catch {
            print("Error fetching username: \(error)")
            // Fallback to email prefix
            return email.components(separatedBy: "@").first ?? "Anonymous"
        }
    }
    
    // Add a new spot
    func addSpot(name: String, latitude: Double, longitude: Double, comment: String) async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "SpotService", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }
        
        let spot = SkateSpot(
            name: name,
            latitude: latitude,
            longitude: longitude,
            comment: comment,
            createdBy: userId
        )
        
        do {
            _ = try db.collection(collectionName).addDocument(from: spot)
            await fetchSpots() // Refresh the list
        } catch {
            print("Error adding spot: \(error)")
            throw error
        }
    }
    
    // Delete a spot
    func deleteSpot(_ spot: SkateSpot) async throws {
        guard let spotId = spot.id else { return }
        guard let userId = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "SpotService", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }
        
        // Check if user owns the spot
        guard spot.createdBy == userId else {
            throw NSError(domain: "SpotService", code: 403, userInfo: [NSLocalizedDescriptionKey: "You can only delete spots you created"])
        }
        
        do {
            try await db.collection(collectionName).document(spotId).delete()
            await fetchSpots() // Refresh the list
        } catch {
            print("Error deleting spot: \(error)")
            throw error
        }
    }
    
    // Update spot coordinates (for dragging)
    func updateSpotLocation(_ spot: SkateSpot, latitude: Double, longitude: Double) async throws {
        guard let spotId = spot.id else { return }
        
        do {
            try await db.collection(collectionName).document(spotId).updateData([
                "latitude": latitude,
                "longitude": longitude,
                "updatedAt": Timestamp(date: Date())
            ])
            await fetchSpots() // Refresh the list
        } catch {
            print("Error updating spot location: \(error)")
            throw error
        }
    }

    // Add comment to a spot
    func addComment(to spot: SkateSpot, text: String) async throws {
        guard let spotId = spot.id else { return }
        guard let currentUser = Auth.auth().currentUser else {
            throw NSError(domain: "SpotService", code: 401, 
                        userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }
        
        let userId = currentUser.uid
        
        // Get username (from Firestore or create default)
        let username = await getCurrentUsername()
        
        let comment = Comment(
            text: text,
            createdBy: userId,
            createdByUsername: username  // ← Use the fetched/created username
        )
        
        do {
            _ = try db.collection(collectionName)
                .document(spotId)
                .collection("comments")
                .addDocument(from: comment)
        } catch {
            print("Error adding comment: \(error)")
            throw error
        }
    }
    
    // Listen to comments for a specific spot (real-time updates)
    func listenToComments(for spot: SkateSpot) -> AnyPublisher<[Comment], Never> {
        guard let spotId = spot.id else {
            return Just([]).eraseToAnyPublisher()
        }
        
        let subject = PassthroughSubject<[Comment], Never>()
        
        db.collection(collectionName)
            .document(spotId)
            .collection("comments")
            .order(by: "createdAt", descending: false)  // Oldest first
            .addSnapshotListener { snapshot, error in
                guard let documents = snapshot?.documents else {
                    print("Error fetching comments: \(error?.localizedDescription ?? "Unknown error")")
                    subject.send([])
                    return
                }
                
                let comments = documents.compactMap { document in
                    try? document.data(as: Comment.self)
                }
                subject.send(comments)
            }
        
        return subject.eraseToAnyPublisher()
    }
    
    // Listen for real-time updates (optional - for real-time sync)
    func listenToSpots() {
        db.collection(collectionName)
            .order(by: "createdAt", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let documents = snapshot?.documents else {
                    print("Error fetching documents: \(error?.localizedDescription ?? "Unknown error")")
                    return
                }
                
                self?.spots = documents.compactMap { document in
                    try? document.data(as: SkateSpot.self)
                }
            }
    }
}

