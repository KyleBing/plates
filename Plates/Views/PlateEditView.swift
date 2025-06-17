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
                    }
                    
                    Button(action: { showingImagePicker = true }) {
                        Text(selectedImage == nil ? "选择照片" : "更换照片")
                    }
                }
            }
            .navigationTitle(editingItem == nil ? "添加车牌" : "编辑车牌")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        saveItem()
                        dismiss()
                    }
                    .disabled(title.isEmpty || plateNumber.isEmpty || selectedImage == nil)
                }
            }
            .sheet(isPresented: $showingImagePicker) {
                ImagePicker(image: $selectedImage)
            }
        }
    }
    
    private func saveItem() {
        guard let image = selectedImage,
              let imageURL = PlateItem.saveImage(image) else { return }
        
        let item = PlateItem(
            id: editingItem?.id ?? UUID(),
            title: title,
            plateNumber: plateNumber,
            vehicleType: vehicleType,
            imageURL: imageURL,
            showCount: editingItem?.showCount ?? 0
        )
        
        if editingItem != nil {
            viewModel.updateItem(item)
        } else {
            viewModel.addItem(item)
        }
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