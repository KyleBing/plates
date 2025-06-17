import SwiftUI

struct LandscapeViewController: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UIViewController {
        let controller = UIViewController()
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        if let windowScene = uiViewController.view.window?.windowScene {
            let geometryPreferences = UIWindowScene.GeometryPreferences.iOS(
                interfaceOrientations: .landscapeRight
            )
            windowScene.requestGeometryUpdate(geometryPreferences) { error in
                print("Error updating orientation: \(error.localizedDescription)")
            }
        }
    }
}

struct PortraitViewController: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UIViewController {
        let controller = UIViewController()
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        if let windowScene = uiViewController.view.window?.windowScene {
            let geometryPreferences = UIWindowScene.GeometryPreferences.iOS(
                interfaceOrientations: .portrait
            )
            windowScene.requestGeometryUpdate(geometryPreferences) { error in
                print("Error updating orientation: \(error.localizedDescription)")
            }
        }
    }
}

struct PlateDetailView: View {
    let item: PlateItem
    @ObservedObject var viewModel: PlateViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var screenBrightness: Double = UIScreen.main.brightness
    @State private var originalBrightness: Double = UIScreen.main.brightness
    @State private var scale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastScale: CGFloat = 1.0
    @State private var lastOffset: CGSize = .zero
    @State private var showingEditSheet = false
    @State private var showControls = true
    @State private var isDismissing = false
    
    private func resetImageState() {
        withAnimation(.spring()) {
            scale = 1.0
            offset = .zero
            lastScale = 1.0
            lastOffset = .zero
        }
    }
    
    private func smoothlyRestoreBrightness() {
        isDismissing = true
        let steps = 20
        let duration: TimeInterval = 0.3
        let stepDuration = duration / TimeInterval(steps)
        let brightnessStep = (screenBrightness - originalBrightness) / Double(steps)
        
        for step in 0..<steps {
            DispatchQueue.main.asyncAfter(deadline: .now() + stepDuration * Double(step)) {
                let newBrightness = screenBrightness - (brightnessStep * Double(step))
                UIScreen.main.brightness = newBrightness
                
                if step == steps - 1 {
                    UIScreen.main.brightness = originalBrightness
                    dismiss()
                }
            }
        }
    }
    
    var body: some View {
        ZStack {
            LandscapeViewController()
                .edgesIgnoringSafeArea(.all)
            
            GeometryReader { geometry in
                ZStack {
                    Color.black.edgesIgnoringSafeArea(.all)
                    
                    if let imageURL = item.imageURL,
                       let image = PlateItem.loadImage(from: imageURL) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .scaleEffect(scale)
                            .offset(offset)
                            .brightness(0)
                            .contrast(1.0)
                            .gesture(
                                SimultaneousGesture(
                                    MagnificationGesture(minimumScaleDelta: 0.01)
                                        .onChanged { value in
                                            let delta = value / lastScale
                                            lastScale = value
                                            scale = min(max(scale * delta, 0.5), 10.0)
                                        }
                                        .onEnded { _ in
                                            lastScale = 1.0
                                        },
                                    DragGesture(minimumDistance: 0)
                                        .onChanged { value in
                                            offset = CGSize(
                                                width: lastOffset.width + value.translation.width,
                                                height: lastOffset.height + value.translation.height
                                            )
                                        }
                                        .onEnded { _ in
                                            lastOffset = offset
                                        }
                                )
                            )
                            .contentShape(Rectangle())
                            .onTapGesture {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    showControls.toggle()
                                }
                            }
                    }
                    
                    VStack {
                        if showControls {
                            HStack {
                                Button(action: { 
                                    smoothlyRestoreBrightness()
                                }) {
                                    Image(systemName: "xmark")
                                        .font(.title)
                                        .foregroundColor(.white)
                                        .padding()
                                }
                                
                                Spacer()
                                
                                Button(action: { showingEditSheet = true }) {
                                    Image(systemName: "pencil")
                                        .font(.title)
                                        .foregroundColor(.white)
                                        .padding()
                                }
                                
                                Button(action: resetImageState) {
                                    Image(systemName: "arrow.counterclockwise")
                                        .font(.title)
                                        .foregroundColor(.white)
                                        .padding()
                                }
                            }
                            .padding(.horizontal)
                            .transition(.move(edge: .top).combined(with: .opacity))
                        }
                        
                        Spacer()
                        
                        if showControls {
                            VStack(spacing: 20) {
                                HStack {
                                    Image(systemName: "sun.min")
                                        .foregroundColor(.white)
                                    Slider(value: Binding(
                                        get: { screenBrightness },
                                        set: { newValue in
                                            screenBrightness = newValue
                                            UIScreen.main.brightness = newValue
                                        }
                                    ), in: 0...1)
                                    .accentColor(.white)
                                    Image(systemName: "sun.max")
                                        .foregroundColor(.white)
                                }
                                .padding(.horizontal)
                            }
                            .padding(.bottom, 10)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            PlateEditView(viewModel: viewModel, editingItem: item)
        }
        .onAppear {
            originalBrightness = UIScreen.main.brightness
            viewModel.incrementShowCount(for: item)
            if let savedState = viewModel.getSavedState(for: item) {
                scale = savedState.scale
                offset = savedState.offset
                lastOffset = savedState.offset
            }
        }
        .onDisappear {
            if !isDismissing {
                UIScreen.main.brightness = originalBrightness
            }
            viewModel.saveState(for: item, scale: scale, offset: offset)
        }
    }
} 
