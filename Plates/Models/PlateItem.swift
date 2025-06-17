import Foundation
import SwiftUI

struct PlateItem: Identifiable, Codable {
    var id = UUID()
    var title: String
    var plateNumber: String
    var vehicleType: VehicleType
    var imageURL: URL?
    var showCount: Int
    
    enum VehicleType: String, Codable, CaseIterable {
        case car = "Car"
        case motorcycle = "Motorcycle"
    }
}

// Extension to handle image persistence
extension PlateItem {
    static func saveImage(_ image: UIImage) -> URL? {
        guard let data = image.jpegData(compressionQuality: 0.8) else { return nil }
        
        // Create a unique filename with timestamp
        let timestamp = Int(Date().timeIntervalSince1970)
        let filename = "\(timestamp)_\(UUID().uuidString).jpg"
        
        // Get the documents directory
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileURL = documentsDirectory.appendingPathComponent(filename)
        
        do {
            try data.write(to: fileURL)
            return fileURL
        } catch {
            print("Error saving image: \(error)")
            return nil
        }
    }
    
    static func loadImage(from url: URL) -> UIImage? {
        do {
            let data = try Data(contentsOf: url)
            return UIImage(data: data)
        } catch {
            print("Error loading image: \(error)")
            return nil
        }
    }
    
    static func deleteImage(at url: URL) {
        do {
            try FileManager.default.removeItem(at: url)
        } catch {
            print("Error deleting image: \(error)")
        }
    }
} 