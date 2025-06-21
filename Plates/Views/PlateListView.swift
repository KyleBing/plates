import SwiftUI
import PhotosUI

struct PlateListView: View {
    @EnvironmentObject var viewModel: PlateViewModel
    @State private var showingAddSheet = false
    @State private var selectedItem: PlateItem?
    @State private var showingEditSheet = false
    @State private var editingItem: PlateItem?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if !viewModel.cloudKitAvailable {
                    HStack {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundColor(.orange)
                        Text("iCloud 同步不可用")
                            .font(.caption)
                            .foregroundColor(.orange)
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .background(Color.orange.opacity(0.1))
                }
                
                // Storage usage indicator
                HStack {
                    Image(systemName: "icloud")
                        .foregroundColor(.blue)
                    Text("存储使用情况")
                        .font(.caption)
                        .fontWeight(.medium)
                    Spacer()
                    let usage = viewModel.getStorageUsage()
                    Text("\(usage.count) 张图片 • \(usage.totalSize)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
                .padding(.vertical, 6)
                .background(Color.blue.opacity(0.05))
                
                List {
                    ForEach(viewModel.plateItems) { item in
                        PlateItemRow(item: item)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedItem = item
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button("编辑") {
                                    showingEditSheet = true
                                    editingItem = item
                                }
                                .tint(.blue)
                                
                                Button("删除", role: .destructive) {
                                    viewModel.deleteItem(item)
                                }
                            }
                    }
                }
            }
            .navigationTitle("车牌管理")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddSheet = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                PlateEditView(viewModel: viewModel)
            }
            .sheet(isPresented: $showingEditSheet) {
                if let editingItem = editingItem {
                    PlateEditView(viewModel: viewModel, editingItem: editingItem)
                }
            }
            .fullScreenCover(item: $selectedItem) { item in
                PlateDetailView(item: item, viewModel: viewModel)
            }
        }
    }
}

struct PlateItemRow: View {
    let item: PlateItem
    @State private var loadedImage: UIImage?
    @State private var isLoadingImage = false
    @State private var hasAttemptedLoad = false
    
    var body: some View {
        HStack {
            if let image = loadedImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 60, height: 60)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else if isLoadingImage {
                ProgressView()
                    .frame(width: 60, height: 60)
            } else {
                Image(systemName: "photo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 60, height: 60)
                    .foregroundColor(.gray)
            }
            
            VStack(alignment: .leading) {
                Text(item.title)
                    .font(.headline)
                Text(item.plateNumber)
                    .font(.subheadline)
                Text(item.vehicleType == .car ? "汽车" : "摩托车")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text("查看次数: \(item.showCount)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
        .onAppear {
            if !hasAttemptedLoad {
                loadImage()
            }
        }
    }
    
    private func loadImage() {
        guard !isLoadingImage else { return }
        
        hasAttemptedLoad = true
        isLoadingImage = true
        
        Task {
            let image = await PlateItem.loadImage(localURL: item.imageURL, cloudID: item.cloudImageID)
            await MainActor.run {
                loadedImage = image
                isLoadingImage = false
            }
        }
    }
} 