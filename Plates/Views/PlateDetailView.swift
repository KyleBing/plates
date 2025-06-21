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
    @State private var showControls = true
    @State private var isDismissing = false
    @State private var loadedImage: UIImage?
    @State private var isLoadingImage = false
    @State private var hasAttemptedLoad = false
    @State private var loadError = false
    @State private var showingResetConfirmation = false
    @State private var imageOpacity: Double = 0.0

    private func resetImageState() {
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
            scale = 1.0
            offset = .zero
            lastScale = 1.0
            lastOffset = .zero
        }
    }

    private func smoothlyRestoreBrightness() {
        isDismissing = true
        
        // Fade out the image and dismiss simultaneously
        withAnimation(.easeInOut(duration: 0.3)) {
            imageOpacity = 0.0
        }
        
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

    private func loadImage() async {
        guard !isLoadingImage else { return }

        hasAttemptedLoad = true
        isLoadingImage = true
        loadError = false

        let image = await PlateItem.loadImage(localURL: item.imageURL, cloudID: item.cloudImageID)

        await MainActor.run {
            loadedImage = image
            isLoadingImage = false
            if image == nil {
                loadError = true
            } else {
                // Fade in the image smoothly
                withAnimation(.easeInOut(duration: 0.5)) {
                    imageOpacity = 1.0
                }
            }
        }
    }

    private func retryLoadImage() {
        // Reset opacity for smooth retry
        imageOpacity = 0.0
        Task {
            await loadImage()
        }
    }

    var body: some View {
        ZStack {
            GeometryReader { geometry in
                ZStack {
                    Color.black
                        .edgesIgnoringSafeArea(.all)

                    if let image = loadedImage {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: geometry.size.width, height: geometry.size.height)
                            .scaleEffect(scale)
                            .offset(offset)
                            .brightness(0)
                            .contrast(1.0)
                            .opacity(imageOpacity)
                            .gesture(
                                SimultaneousGesture(
                                    MagnificationGesture(minimumScaleDelta: 0.01)
                                        .onChanged { value in
                                            let delta = value / lastScale
                                            lastScale = value
                                            scale = min(max(scale * delta, 0.1), 20.0)
                                        }
                                        .onEnded { _ in
                                            lastScale = 1.0
                                        },
                                    DragGesture(minimumDistance: 0)
                                        .onChanged { value in
                                            let newOffset = CGSize(
                                                width: lastOffset.width + value.translation.width,
                                                height: lastOffset.height + value.translation.height
                                            )
                                            
                                            // Allow some overflow but prevent excessive dragging
                                            let maxOffset = geometry.size.width * 0.5 * scale
                                            offset = CGSize(
                                                width: max(-maxOffset, min(maxOffset, newOffset.width)),
                                                height: max(-maxOffset, min(maxOffset, newOffset.height))
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
                            .onTapGesture(count: 2) {
                                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                                    if scale > 1.0 {
                                        // Reset to original size
                                        scale = 1.0
                                        offset = .zero
                                        lastOffset = .zero
                                    } else {
                                        // Zoom to 2x
                                        scale = 2.0
                                    }
                                }
                            }
                    } else if isLoadingImage {
                        VStack {
                            ProgressView("加载图片中...")
                                .foregroundColor(.white)
                            Text("正在从云端下载...")
                                .foregroundColor(.white)
                                .font(.caption)
                                .padding(.top, 8)
                        }
                    } else if loadError {
                        VStack(spacing: 16) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.largeTitle)
                                .foregroundColor(.white)
                            Text("图片加载失败")
                                .foregroundColor(.white)
                                .font(.headline)
                            Text("无法从本地或云端加载图片")
                                .foregroundColor(.white.opacity(0.8))
                                .font(.caption)
                                .multilineTextAlignment(.center)
                            Button(action: retryLoadImage) {
                                HStack {
                                    Image(systemName: "arrow.clockwise")
                                    Text("重试")
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                                .background(Color.blue)
                                .cornerRadius(8)
                            }
                        }
                        .padding()
                    }

                    VStack {
                        if showControls {
                            HStack {
                                Button(action: { 
                                    smoothlyRestoreBrightness()
                                }) {
                                    Image(systemName: "xmark")
                                        .font(.title2)
                                        .foregroundColor(.white)
                                        .frame(width: 44, height: 44)
                                        .background(.ultraThinMaterial, in: Circle())
                                }
                                
                                Spacer()
                                
                                Button(action: { showingResetConfirmation = true }) {
                                    Image(systemName: "arrow.counterclockwise")
                                        .font(.title2)
                                        .foregroundColor(.white)
                                        .frame(width: 44, height: 44)
                                        .background(.ultraThinMaterial, in: Circle())
                                }
                            }
                            .padding(.horizontal)
                            .padding(.top, geometry.safeAreaInsets.top + 20)
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
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                            }
                            .padding(.horizontal)
                            .padding(.bottom, geometry.safeAreaInsets.bottom + 20)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
                    }
                }
                .clipped()
            }
        }
        .edgesIgnoringSafeArea(.all)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .statusBarHidden(true)
        .onAppear {
            originalBrightness = UIScreen.main.brightness
            viewModel.incrementShowCount(for: item)
            if let savedState = viewModel.getSavedState(for: item) {
                scale = savedState.scale
                offset = savedState.offset
                lastOffset = savedState.offset
            }
            Task {
                await loadImage()
            }
        }
        .onDisappear {
            if !isDismissing {
                UIScreen.main.brightness = originalBrightness
            }
            viewModel.saveState(for: item, scale: scale, offset: offset)
        }
        .confirmationDialog(
            "重置图片大小",
            isPresented: $showingResetConfirmation,
            titleVisibility: .visible
        ) {
            Button("重置", role: .destructive) {
                resetImageState()
            }
            Button("取消", role: .cancel) { }
        } message: {
            Text("确定要重置图片的大小和位置吗？此操作无法撤销。")
        }
    }
}
