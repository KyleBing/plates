import SwiftUI

class OrientationViewController: UIViewController {
    var targetOrientation: UIInterfaceOrientationMask = .landscape
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        setOrientation(targetOrientation)
    }
    
    func setOrientation(_ orientation: UIInterfaceOrientationMask) {
        guard let windowScene = view.window?.windowScene else {
            // Retry after a short delay if windowScene is not available yet
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.setOrientation(orientation)
            }
            return
        }
        
        let geometryPreferences = UIWindowScene.GeometryPreferences.iOS(
            interfaceOrientations: orientation
        )
        windowScene.requestGeometryUpdate(geometryPreferences) { (error: any Error) in
            print("Error updating orientation: \(error.localizedDescription)")
        }
    }
}

struct LandscapeViewController: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> OrientationViewController {
        let controller = OrientationViewController()
        controller.targetOrientation = .landscape
        return controller
    }

    func updateUIViewController(_ uiViewController: OrientationViewController, context: Context) {
        uiViewController.setOrientation(.landscape)
    }
}

struct PortraitViewController: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> OrientationViewController {
        let controller = OrientationViewController()
        controller.targetOrientation = .portrait
        return controller
    }

    func updateUIViewController(_ uiViewController: OrientationViewController, context: Context) {
        uiViewController.setOrientation(.portrait)
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
    @State private var showControls = false
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
        
        // Restore portrait orientation before dismissing
        if let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }) {
            let geometryPreferences = UIWindowScene.GeometryPreferences.iOS(
                interfaceOrientations: .portrait
            )
            windowScene.requestGeometryUpdate(geometryPreferences) { (error: any Error) in
                print("Error restoring orientation: \(error.localizedDescription)")
            }
        }
        
        // Fade out the image and dismiss simultaneously
        withAnimation(.easeInOut(duration: 0.3)) {
            imageOpacity = 0.0
        }
        
        // Dismiss immediately while the fade-out animation is running
        dismiss()
        
        // Restore brightness in the background
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
                }
            }
        }
    }

    private func loadImage() async {
        guard !isLoadingImage else { return }

        hasAttemptedLoad = true
        isLoadingImage = true
        loadError = false

        let image = await PlateItem.loadImage(
            localURL: item.imageURL, 
            cloudID: item.cloudImageID,
            cachedLocalURL: item.cachedLocalURL
        ) { cachedURL in
            // Update the cached URL in the view model
            Task { @MainActor in
                viewModel.updateCachedLocalURL(for: item, cachedURL: cachedURL)
            }
        }

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
                        .contentShape(Rectangle())
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                showControls.toggle()
                            }
                        }

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
                                    ),
                                    TapGesture()
                                        .onEnded { _ in
                                            withAnimation(.easeInOut(duration: 0.3)) {
                                                showControls.toggle()
                                            }
                                        }
                                )
                            )
                            .contentShape(Rectangle())
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
                        VStack(spacing: 12) {
                            ProgressView("加载图片中...")
                                .tint(.white)
                                .foregroundStyle(.white)
                            Text("正在从云端下载...")
                                .foregroundStyle(.white)
                                .font(.caption)
                                .fontWeight(.medium)
                                .padding(.top, 8)
                        }
                    } else if loadError {
                        VStack(spacing: 16) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.largeTitle)
                                .fontWeight(.medium)
                                .foregroundStyle(.white)
                                .symbolRenderingMode(.hierarchical)
                            Text("图片加载失败")
                                .foregroundStyle(.white)
                                .font(.headline)
                                .fontWeight(.semibold)
                            Text("无法从本地或云端加载图片")
                                .foregroundStyle(.white.opacity(0.8))
                                .font(.caption)
                                .multilineTextAlignment(.center)
                            Button(action: retryLoadImage) {
                                HStack(spacing: 8) {
                                    Image(systemName: "arrow.clockwise")
                                        .fontWeight(.semibold)
                                    Text("重试")
                                        .fontWeight(.semibold)
                                }
                                .foregroundStyle(.white)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 14)
                                .background {
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(.ultraThinMaterial)
                                        .shadow(color: .black.opacity(0.3), radius: 12, x: 0, y: 6)
                                        .shadow(color: .white.opacity(0.1), radius: 1, x: 0, y: -1)
                                }
                                .overlay {
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(.white.opacity(0.2), lineWidth: 1)
                                }
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
                                        .fontWeight(.semibold)
                                        .foregroundStyle(.white)
                                        .symbolRenderingMode(.hierarchical)
                                        .frame(width: 56, height: 56)
                                        .background {
                                            Circle()
                                                .fill(.ultraThinMaterial)
                                                .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
                                                .shadow(color: .white.opacity(0.1), radius: 1, x: 0, y: -1)
                                        }
                                        .overlay {
                                            Circle()
                                                .stroke(.white.opacity(0.2), lineWidth: 1)
                                        }
                                }
                                
                                Spacer()
                                
                                Button(action: { showingResetConfirmation = true }) {
                                    Image(systemName: "arrow.counterclockwise")
                                        .font(.title2)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(.white)
                                        .symbolRenderingMode(.hierarchical)
                                        .frame(width: 56, height: 56)
                                        .background {
                                            Circle()
                                                .fill(.ultraThinMaterial)
                                                .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
                                                .shadow(color: .white.opacity(0.1), radius: 1, x: 0, y: -1)
                                        }
                                        .overlay {
                                            Circle()
                                                .stroke(.white.opacity(0.2), lineWidth: 1)
                                        }
                                }
                            }
                            .padding(.horizontal)
                            .padding(.top, geometry.safeAreaInsets.top + 20)
                            .transition(.move(edge: .top).combined(with: .opacity))
                        }

                        Spacer()

                        if showControls {
                            VStack(spacing: 20) {
                                HStack(spacing: 12) {
                                    Image(systemName: "sun.min")
                                        .font(.title3)
                                        .fontWeight(.medium)
                                        .foregroundStyle(.white)
                                        .symbolRenderingMode(.hierarchical)
                                    
                                    Slider(value: Binding(
                                        get: { screenBrightness },
                                        set: { newValue in
                                            screenBrightness = newValue
                                            UIScreen.main.brightness = newValue
                                        }
                                    ), in: 0...1)
                                    .tint(.white)
                                    
                                    Image(systemName: "sun.max")
                                        .font(.title3)
                                        .fontWeight(.medium)
                                        .foregroundStyle(.white)
                                        .symbolRenderingMode(.hierarchical)
                                }
                                .padding(.horizontal, 20)
                                .padding(.vertical, 16)
                                .background {
                                    RoundedRectangle(cornerRadius: 20)
                                        .fill(.ultraThinMaterial)
                                        .shadow(color: .black.opacity(0.3), radius: 15, x: 0, y: 8)
                                        .shadow(color: .white.opacity(0.1), radius: 1, x: 0, y: -1)
                                }
                                .overlay {
                                    RoundedRectangle(cornerRadius: 20)
                                        .stroke(.white.opacity(0.2), lineWidth: 1)
                                }
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
        .background(
            LandscapeViewController()
                .allowsHitTesting(false)
        )
        .onAppear {
            originalBrightness = UIScreen.main.brightness
            viewModel.incrementShowCount(for: item)
            if let savedState = viewModel.getSavedState(for: item) {
                scale = savedState.scale
                offset = savedState.offset
                lastOffset = savedState.offset
            }
            
            // Set landscape orientation with retry mechanism
            func setLandscapeOrientation(retryCount: Int = 0) {
                guard retryCount < 10 else {
                    print("Failed to set landscape orientation after multiple attempts")
                    return
                }
                
                if let windowScene = UIApplication.shared.connectedScenes
                    .compactMap({ $0 as? UIWindowScene })
                    .first(where: { $0.activationState == .foregroundActive }),
                   let _ = windowScene.windows.first {
                    
                    let geometryPreferences = UIWindowScene.GeometryPreferences.iOS(
                        interfaceOrientations: .landscape
                    )
                    windowScene.requestGeometryUpdate(geometryPreferences) { (error: any Error) in
                        print("Error setting landscape orientation (attempt \(retryCount + 1)): \(error.localizedDescription)")
                        if retryCount < 9 {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                setLandscapeOrientation(retryCount: retryCount + 1)
                            }
                        }
                    }
                } else {
                    // Retry if windowScene is not ready
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        setLandscapeOrientation(retryCount: retryCount + 1)
                    }
                }
            }
            
            // Start setting orientation after a brief delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                setLandscapeOrientation()
            }
            
            Task {
                await loadImage()
            }
        }
        .onDisappear {
            if !isDismissing {
                UIScreen.main.brightness = originalBrightness
            }
            
            // Restore portrait orientation when leaving the view
            if let windowScene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first(where: { $0.activationState == .foregroundActive }) {
                let geometryPreferences = UIWindowScene.GeometryPreferences.iOS(
                    interfaceOrientations: .portrait
                )
                windowScene.requestGeometryUpdate(geometryPreferences) { (error: any Error) in
                    print("Error restoring orientation: \(error.localizedDescription)")
                }
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
