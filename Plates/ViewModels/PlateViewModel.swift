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

class PlateViewModel: ObservableObject {
    @Published var plateItems: [PlateItem] = []
    private let saveKey = "savedPlateItems"
    private let stateKey = "savedImageStates"
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
        if let imageURL = item.imageURL {
            try? FileManager.default.removeItem(at: imageURL)
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