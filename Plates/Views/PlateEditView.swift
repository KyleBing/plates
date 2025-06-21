import SwiftUI
import PhotosUI

struct PlateEditView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: PlateViewModel
    
    @State private var title = ""
    @State private var plateNumber = ""
    @State private var vehicleType = PlateItem.VehicleType.car
    @State private var selectedImage: UIImage?
    @State private var showingImagePicker = false
    @State private var isSaving = false
    
    var editingItem: PlateItem?
    
    init(viewModel: PlateViewModel, editingItem: PlateItem? = nil) {
        self.viewModel = viewModel
        self.editingItem = editingItem
        
        if let item = editingItem {
            _title = State(initialValue: item.title)
            _plateNumber = State(initialValue: item.plateNumber)
            _vehicleType = State(initialValue: item.vehicleType)
            if let imageURL = item.imageURL {
                _selectedImage = State(initialValue: PlateItem.loadImage(from: imageURL))
            }
        }
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("车牌信息")) {
                    TextField("标题", text: $title)
                    HStack {
                        TextField("车牌号码", text: $plateNumber)
                        Button(action: {
                            plateNumber = title
                        }) {
                            Image(systemName: "arrow.right.circle")
                                .foregroundColor(.blue)
                        }
                        .disabled(title.isEmpty)
                    }
                    Picker("车辆类型", selection: $vehicleType) {
                        Text("汽车").tag(PlateItem.VehicleType.car)
                        Text("摩托车").tag(PlateItem.VehicleType.motorcycle)
                    }
                }
                
                Section(header: Text("照片")) {
                    if let image = selectedImage {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 200)
                        
                        // Show image size info
                        let imageSize = image.jpegData(compressionQuality: 0.8)?.count ?? 0
                        let sizeInMB = Double(imageSize) / (1024 * 1024)
                        
                        HStack {
                            Image(systemName: "info.circle")
                                .foregroundColor(.blue)
                            Text("图片大小: \(String(format: "%.1f", sizeInMB)) MB")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            if sizeInMB > 10 {
                                Text("⚠️ 文件较大")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                            }
                        }
                        .padding(.top, 4)
                    }
                    
                    // Only show image picker for new items, not when editing
                    if editingItem == nil {
                        Button(action: { showingImagePicker = true }) {
                            Text(selectedImage == nil ? "选择照片" : "更换照片")
                        }
                    } else {
                        Text("编辑时无法更换照片")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    // iCloud storage reminder
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Image(systemName: "icloud")
                                .foregroundColor(.blue)
                            Text("iCloud 存储提醒")
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        
                        Text("• 建议图片大小不超过 10MB")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text("• 大图片会占用更多 iCloud 空间")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text("• 图片会自动压缩以节省空间")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 8)
                }
            }
            .navigationTitle(editingItem == nil ? "添加车牌" : "编辑车牌")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                    .disabled(isSaving)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        Task {
                            await saveItem()
                        }
                    }
                    .disabled(title.isEmpty || plateNumber.isEmpty || (editingItem == nil && selectedImage == nil) || isSaving)
                }
            }
            .sheet(isPresented: $showingImagePicker) {
                ImagePicker(image: $selectedImage)
            }
            .overlay(
                Group {
                    if isSaving {
                        VStack {
                            ProgressView("保存中...")
                                .padding()
                                .background(Color(.systemBackground))
                                .cornerRadius(10)
                                .shadow(radius: 5)
                        }
                    }
                }
            )
        }
    }
    
    private func saveItem() async {
        isSaving = true
        
        if let editingItem = editingItem {
            // Editing existing item - only update non-image fields
            var updatedItem = editingItem
            updatedItem.title = title
            updatedItem.plateNumber = plateNumber
            updatedItem.vehicleType = vehicleType
            
            await MainActor.run {
                viewModel.updateItem(updatedItem)
            }
        } else {
            // Adding new item - save image and create new item
            guard let image = selectedImage else { return }
            
            let success = await viewModel.saveItemWithImage(
                title: title,
                plateNumber: plateNumber,
                vehicleType: vehicleType,
                image: image,
                editingItem: nil
            )
            
            if !success {
                // Handle save failure
                return
            }
        }
        
        isSaving = false
        dismiss()
    }
}

struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .images
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            parent.dismiss()
            
            guard let provider = results.first?.itemProvider else { return }
            
            if provider.canLoadObject(ofClass: UIImage.self) {
                provider.loadObject(ofClass: UIImage.self) { image, _ in
                    DispatchQueue.main.async {
                        self.parent.image = image as? UIImage
                    }
                }
            }
        }
    }
} 