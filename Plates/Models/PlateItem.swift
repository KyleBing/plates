import Foundation
import SwiftUI
import CloudKit

struct PlateItem: Identifiable, Codable {
    var id = UUID()
    var title: String
    var plateNumber: String
    var vehicleType: VehicleType
    var imageURL: URL?
    var cloudImageID: String? // Store CloudKit record ID for cloud images
    var showCount: Int
    
    enum VehicleType: String, Codable, CaseIterable {
        case car = "Car"
        case motorcycle = "Motorcycle"
    }
}

// Extension to handle image persistence with cloud storage
extension PlateItem {
    static func saveImage(_ image: UIImage) async -> (localURL: URL?, cloudID: String?) {
        // Optimize image size for iCloud storage
        let optimizedImage = optimizeImageForStorage(image)
        
        guard let data = optimizedImage.jpegData(compressionQuality: 0.8) else { 
            return (nil, nil) 
        }
        
        // Check file size and warn if too large
        let sizeInMB = Double(data.count) / (1024 * 1024)
        if sizeInMB > 10 {
            print("Warning: Image size is \(String(format: "%.1f", sizeInMB)) MB, which may impact iCloud storage")
        }
        
        // Create a unique filename with timestamp
        let timestamp = Int(Date().timeIntervalSince1970)
        let filename = "\(timestamp)_\(UUID().uuidString).jpg"
        
        // Get the documents directory
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileURL = documentsDirectory.appendingPathComponent(filename)
        
        // Save to local storage
        var localURL: URL?
        do {
            try data.write(to: fileURL)
            localURL = fileURL
        } catch {
            print("Error saving image locally: \(error)")
        }
        
        // Save to iCloud
        let cloudID = await CloudStorageService.shared.uploadImage(data, filename: filename)
        
        return (localURL, cloudID)
    }
    
    // Optimize image for storage by reducing size if too large
    private static func optimizeImageForStorage(_ image: UIImage) -> UIImage {
        let maxDimension: CGFloat = 2048 // Maximum dimension for storage optimization
        let maxFileSize: Int = 10 * 1024 * 1024 // 10MB limit
        
        // Check if image needs resizing
        let originalSize = image.size
        if originalSize.width <= maxDimension && originalSize.height <= maxDimension {
            // Check file size
            if let data = image.jpegData(compressionQuality: 0.8), data.count <= maxFileSize {
                return image // No optimization needed
            }
        }
        
        // Calculate new size while maintaining aspect ratio
        let scale = min(maxDimension / originalSize.width, maxDimension / originalSize.height)
        let newSize = CGSize(width: originalSize.width * scale, height: originalSize.height * scale)
        
        // Resize image
        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        image.draw(in: CGRect(origin: .zero, size: newSize))
        let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        guard let optimizedImage = resizedImage else { return image }
        
        // Try different compression qualities to get under 10MB
        let compressionQualities: [CGFloat] = [0.8, 0.6, 0.4, 0.2]
        
        for quality in compressionQualities {
            if let data = optimizedImage.jpegData(compressionQuality: quality) {
                if data.count <= maxFileSize {
                    print("Image optimized: \(String(format: "%.1f", Double(data.count) / (1024 * 1024))) MB with quality \(quality)")
                    return optimizedImage
                }
            }
        }
        
        // If still too large, return the resized image with lowest quality
        print("Warning: Image could not be compressed below 10MB")
        return optimizedImage
    }
    
    static func loadImage(from url: URL) -> UIImage? {
        // Check if file exists before trying to load
        guard FileManager.default.fileExists(atPath: url.path) else {
            // Don't log this as an error since we have cloud fallback
            return nil
        }
        
        do {
            let data = try Data(contentsOf: url)
            return UIImage(data: data)
        } catch {
            print("Error loading image from local storage: \(error)")
            return nil
        }
    }
    
    static func loadImageFromCloud(cloudID: String) async -> UIImage? {
        return await CloudStorageService.shared.downloadImage(cloudID: cloudID)
    }
    
    static func deleteImage(at url: URL, cloudID: String? = nil) {
        // Delete from local storage only if file exists
        if FileManager.default.fileExists(atPath: url.path) {
            do {
                try FileManager.default.removeItem(at: url)
            } catch {
                print("Error deleting image from local storage: \(error)")
            }
        }
        
        // Delete from cloud storage
        if let cloudID = cloudID {
            Task {
                await CloudStorageService.shared.deleteImage(cloudID: cloudID)
            }
        }
    }
    
    // Helper method to load image from either local or cloud storage
    static func loadImage(localURL: URL?, cloudID: String?) async -> UIImage? {
        // Try local storage first
        if let localURL = localURL {
            if let image = loadImage(from: localURL) {
                return image
            }
        }
        
        // Fall back to cloud storage
        if let cloudID = cloudID {
            return await loadImageFromCloud(cloudID: cloudID)
        }
        
        return nil
    }
}

// Cloud Storage Service
class CloudStorageService {
    static let shared = CloudStorageService()
    private let container = CKContainer.default()
    private let database: CKDatabase
    private var isCloudKitAvailable = true
    
    private init() {
        self.database = container.privateCloudDatabase
    }
    
    func uploadImage(_ imageData: Data, filename: String) async -> String? {
        guard isCloudKitAvailable else {
            print("CloudKit is not available, skipping upload")
            return nil
        }
        
        // Retry mechanism for temporary network issues
        for attempt in 1...3 {
            do {
                // Create a temporary file for upload
                let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
                try imageData.write(to: tempURL)
                
                // Create CloudKit asset
                let asset = CKAsset(fileURL: tempURL)
                
                // Create record
                let record = CKRecord(recordType: "PlateImage")
                record["imageAsset"] = asset
                record["filename"] = filename
                record["uploadDate"] = Date()
                
                // Save to CloudKit
                let savedRecord = try await database.save(record)
                
                // Clean up temporary file
                try? FileManager.default.removeItem(at: tempURL)
                
                return savedRecord.recordID.recordName
            } catch let error as CKError {
                print("CloudKit error uploading image (attempt \(attempt)/3): \(error.localizedDescription)")
                
                // Handle specific CloudKit errors
                switch error.code {
                case .serverRejectedRequest:
                    print("Server rejected request - CloudKit container may not be properly configured")
                    isCloudKitAvailable = false
                    return nil
                case .notAuthenticated:
                    print("User not authenticated with iCloud")
                    isCloudKitAvailable = false
                    return nil
                case .quotaExceeded:
                    print("iCloud quota exceeded")
                    isCloudKitAvailable = false
                    return nil
                case .networkUnavailable, .networkFailure:
                    if attempt < 3 {
                        print("Network issue, retrying in 2 seconds...")
                        try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
                        continue
                    } else {
                        print("Network failed after 3 attempts")
                        return nil
                    }
                default:
                    if attempt < 3 {
                        print("Other CloudKit error, retrying in 2 seconds...")
                        try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
                        continue
                    } else {
                        print("CloudKit error after 3 attempts: \(error.code)")
                        return nil
                    }
                }
            } catch {
                print("Error uploading image to CloudKit: \(error)")
                return nil
            }
        }
        
        return nil
    }
    
    func downloadImage(cloudID: String) async -> UIImage? {
        guard isCloudKitAvailable else {
            print("CloudKit is not available, cannot download image")
            return nil
        }
        
        do {
            let recordID = CKRecord.ID(recordName: cloudID)
            let record = try await database.record(for: recordID)
            
            guard let asset = record["imageAsset"] as? CKAsset,
                  let fileURL = asset.fileURL else {
                print("No asset or file URL found in CloudKit record")
                return nil
            }
            
            // Check if the file exists at the CloudKit URL
            guard FileManager.default.fileExists(atPath: fileURL.path) else {
                print("CloudKit asset file does not exist at path: \(fileURL.path)")
                return nil
            }
            
            let imageData = try Data(contentsOf: fileURL)
            return UIImage(data: imageData)
        } catch let error as CKError {
            print("CloudKit error downloading image: \(error.localizedDescription)")
            
            switch error.code {
            case .serverRejectedRequest:
                print("Server rejected request - CloudKit container may not be properly configured")
                isCloudKitAvailable = false
            case .notAuthenticated:
                print("User not authenticated with iCloud")
                isCloudKitAvailable = false
            case .networkUnavailable:
                print("Network unavailable for CloudKit")
            default:
                print("Other CloudKit error: \(error.code)")
            }
            
            return nil
        } catch {
            print("Error downloading image from CloudKit: \(error)")
            return nil
        }
    }
    
    func deleteImage(cloudID: String) async {
        guard isCloudKitAvailable else {
            print("CloudKit is not available, cannot delete image")
            return
        }
        
        do {
            let recordID = CKRecord.ID(recordName: cloudID)
            try await database.deleteRecord(withID: recordID)
        } catch let error as CKError {
            print("CloudKit error deleting image: \(error.localizedDescription)")
            
            switch error.code {
            case .serverRejectedRequest:
                print("Server rejected request - CloudKit container may not be properly configured")
                isCloudKitAvailable = false
            case .notAuthenticated:
                print("User not authenticated with iCloud")
                isCloudKitAvailable = false
            default:
                print("Other CloudKit error: \(error.code)")
            }
        } catch {
            print("Error deleting image from CloudKit: \(error)")
        }
    }
    
    // Migration helper: Upload existing local image to cloud
    func migrateLocalImageToCloud(localURL: URL) async -> String? {
        // Check if local file exists before attempting migration
        guard FileManager.default.fileExists(atPath: localURL.path) else {
            // File may already be in cloud storage, skip migration
            return nil
        }
        
        guard let imageData = try? Data(contentsOf: localURL) else { 
            print("Failed to read image data for migration")
            return nil 
        }
        
        let filename = localURL.lastPathComponent
        return await uploadImage(imageData, filename: filename)
    }
    
    // Check CloudKit availability
    func checkCloudKitAvailability() async -> Bool {
        do {
            // Try to fetch user record to test CloudKit connectivity
            let userRecordID = try await container.userRecordID()
            print("CloudKit is available for user: \(userRecordID.recordName)")
            isCloudKitAvailable = true
            return true
        } catch {
            print("CloudKit is not available: \(error.localizedDescription)")
            isCloudKitAvailable = false
            return false
        }
    }
} 