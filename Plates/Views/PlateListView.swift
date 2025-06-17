import SwiftUI
import PhotosUI

struct PlateListView: View {
    @StateObject private var viewModel = PlateViewModel()
    @State private var showingAddSheet = false
    @State private var selectedItem: PlateItem?
    
    var body: some View {
        NavigationView {
            List {
                ForEach(viewModel.plateItems) { item in
                    PlateItemRow(item: item)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedItem = item
                        }
                }
                .onDelete { indexSet in
                    indexSet.forEach { index in
                        viewModel.deleteItem(viewModel.plateItems[index])
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
            .fullScreenCover(item: $selectedItem) { item in
                PlateDetailView(item: item, viewModel: viewModel)
            }
        }
    }
}

struct PlateItemRow: View {
    let item: PlateItem
    
    var body: some View {
        HStack {
            if let imageURL = item.imageURL,
               let image = PlateItem.loadImage(from: imageURL) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 60, height: 60)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
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
    }
} 