import Foundation
import SwiftUI

struct ImageState: Codable {
    let scale: CGFloat
    let offset: CGSize
    
    enum CodingKeys: String, CodingKey {
        case scale
        case offsetX
        case offsetY
    }
    
    init(scale: CGFloat, offset: CGSize) {
        self.scale = scale
        self.offset = offset
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        scale = try container.decode(CGFloat.self, forKey: .scale)
        let offsetX = try container.decode(CGFloat.self, forKey: .offsetX)
        let offsetY = try container.decode(CGFloat.self, forKey: .offsetY)
        offset = CGSize(width: offsetX, height: offsetY)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(scale, forKey: .scale)
        try container.encode(offset.width, forKey: .offsetX)
        try container.encode(offset.height, forKey: .offsetY)
    }
}

@MainActor
class PlateViewModel: ObservableObject {
    @Published var plateItems: [PlateItem] = []
    @Published var isLoading = false
    @Published var cloudKitAvailable = true
    private let saveKey = "savedPlateItems"
    private let stateKey = "savedImageStates"
    private let migrationKey = "hasMigratedToCloud"
    private var imageStates: [UUID: ImageState] = [:]
    
    init() {
        loadItems()
        loadStates()
    }
    
    func addItem(_ item: PlateItem) {
        plateItems.append(item)
        saveItems()
    }
    
    func updateItem(_ item: PlateItem) {
        if let index = plateItems.firstIndex(where: { $0.id == item.id }) {
            plateItems[index] = item
            saveItems()
        }
    }
    
    func deleteItem(_ item: PlateItem) {
        plateItems.removeAll { $0.id == item.id }
        imageStates.removeValue(forKey: item.id)
        
        // Delete both local and cloud images
        if let imageURL = item.imageURL {
            PlateItem.deleteImage(at: imageURL, cloudID: item.cloudImageID, cachedLocalURL: item.cachedLocalURL)
        }
        
        saveItems()
        saveStates()
    }
    
    func incrementShowCount(for item: PlateItem) {
        if let index = plateItems.firstIndex(where: { $0.id == item.id }) {
            plateItems[index].showCount += 1
            saveItems()
        }
    }
    
    func saveState(for item: PlateItem, scale: CGFloat, offset: CGSize) {
        imageStates[item.id] = ImageState(scale: scale, offset: offset)
        saveStates()
    }
    
    func getSavedState(for item: PlateItem) -> ImageState? {
        return imageStates[item.id]
    }
    
    // Update cached local URL when image is downloaded from cloud
    func updateCachedLocalURL(for item: PlateItem, cachedURL: URL) {
        if let index = plateItems.firstIndex(where: { $0.id == item.id }) {
            var updatedItem = item
            updatedItem.cachedLocalURL = cachedURL
            plateItems[index] = updatedItem
            saveItems()
        }
    }
    
    // Calculate storage usage
    func getStorageUsage() -> (count: Int, totalSize: String) {
        let count = plateItems.count
        
        // Calculate total size of local files
        var totalSize: Int64 = 0
        for item in plateItems {
            if let imageURL = item.imageURL,
               FileManager.default.fileExists(atPath: imageURL.path) {
                if let attributes = try? FileManager.default.attributesOfItem(atPath: imageURL.path),
                   let fileSize = attributes[.size] as? Int64 {
                    totalSize += fileSize
                }
            }
        }
        
        let totalSizeMB = Double(totalSize) / (1024 * 1024)
        let sizeString = String(format: "%.1f MB", totalSizeMB)
        
        return (count, sizeString)
    }
    
    // Async method to save image and create item
    func saveItemWithImage(title: String, plateNumber: String, vehicleType: PlateItem.VehicleType, image: UIImage, editingItem: PlateItem? = nil) async -> Bool {
        isLoading = true
        
        defer { 
            Task { @MainActor in
                self.isLoading = false
            }
        }
        
        let result = await PlateItem.saveImage(image)
        
        guard let localURL = result.localURL else {
            print("Failed to save image")
            return false
        }
        
        let item = PlateItem(
            id: editingItem?.id ?? UUID(),
            title: title,
            plateNumber: plateNumber,
            vehicleType: vehicleType,
            imageURL: localURL,
            cloudImageID: result.cloudID,
            cachedLocalURL: nil,
            showCount: editingItem?.showCount ?? 0
        )
        
        await MainActor.run {
            if editingItem != nil {
                self.updateItem(item)
            } else {
                self.addItem(item)
            }
        }
        
        return true
    }
    
    // Migration method to upload existing local images to cloud
    func migrateExistingImagesToCloud() async {
        // Check if migration has already been performed
        if UserDefaults.standard.bool(forKey: migrationKey) {
            return
        }
        
        await MainActor.run {
            isLoading = true
        }
        
        defer { 
            Task { @MainActor in
                self.isLoading = false
            }
        }
        
        // Check CloudKit availability first
        let cloudKitAvailable = await CloudStorageService.shared.checkCloudKitAvailability()
        
        await MainActor.run {
            self.cloudKitAvailable = cloudKitAvailable
        }
        
        if !cloudKitAvailable {
            print("CloudKit is not available, skipping migration")
            // Mark migration as complete even if CloudKit is not available
            // to prevent repeated attempts
            UserDefaults.standard.set(true, forKey: migrationKey)
            return
        }
        
        var hasChanges = false
        
        for (index, item) in plateItems.enumerated() {
            if let imageURL = item.imageURL, item.cloudImageID == nil {
                if let cloudID = await CloudStorageService.shared.migrateLocalImageToCloud(localURL: imageURL) {
                    var updatedItem = item
                    updatedItem.cloudImageID = cloudID
                    await MainActor.run {
                        self.plateItems[index] = updatedItem
                    }
                    hasChanges = true
                }
            }
        }
        
        if hasChanges {
            await MainActor.run {
                saveItems()
            }
        }
        
        // Mark migration as complete
        UserDefaults.standard.set(true, forKey: migrationKey)
    }
    
    private func saveItems() {
        if let encoded = try? JSONEncoder().encode(plateItems) {
            UserDefaults.standard.set(encoded, forKey: saveKey)
        }
    }
    
    private func loadItems() {
        if let data = UserDefaults.standard.data(forKey: saveKey),
           let decoded = try? JSONDecoder().decode([PlateItem].self, from: data) {
            plateItems = decoded
        }
    }
    
    private func saveStates() {
        if let encoded = try? JSONEncoder().encode(imageStates) {
            UserDefaults.standard.set(encoded, forKey: stateKey)
        }
    }
    
    private func loadStates() {
        if let data = UserDefaults.standard.data(forKey: stateKey),
           let decoded = try? JSONDecoder().decode([UUID: ImageState].self, from: data) {
            imageStates = decoded
        }
    }
} 