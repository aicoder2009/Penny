//
//  CameraAffordabilityView.swift
//  Penny
//
//  Created by Kiro on 8/17/25.
//

import SwiftUI
import AVFoundation
import VisionKit
import Vision

// MARK: - Camera Affordability View

struct CameraAffordabilityView: View {
    @StateObject private var viewModel = CameraAffordabilityViewModel()
    @Environment(\.dismiss) private var dismiss
    let budgetViewModel: BudgetViewModel
    
    init(budgetViewModel: BudgetViewModel = BudgetViewModel()) {
        self.budgetViewModel = budgetViewModel
    }
    
    var body: some View {
        ZStack {
            // Full-screen camera preview
            CameraPreviewView(session: viewModel.captureSession)
                .ignoresSafeArea()
            
            // Camera overlay with Penny's design system
            VStack {
                // Top bar with close button
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                            .background(Color.black.opacity(0.3))
                            .clipShape(Circle())
                    }
                    
                    Spacer()
                    
                    Text("Point at an item")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.black.opacity(0.3))
                        .cornerRadius(20)
                    
                    Spacer()
                }
                .padding()
                
                Spacer()
                
                // Detection status indicator
                if viewModel.isProcessing {
                    VStack {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(1.2)
                        
                        Text("Analyzing...")
                            .font(.caption)
                            .foregroundColor(.white)
                            .padding(.top, 8)
                    }
                    .padding()
                    .background(Color.black.opacity(0.3))
                    .cornerRadius(12)
                }
                
                Spacer()
            }
            
            // Affordability Result Card
            if viewModel.showingResultCard, let result = viewModel.currentAffordabilityResult {
                VStack {
                    Spacer()
                    AffordabilityResultCard(result: result, budgetViewModel: budgetViewModel) {
                        viewModel.showingResultCard = false
                        viewModel.currentAffordabilityResult = nil
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                .animation(.spring(response: 0.6, dampingFraction: 0.8), value: viewModel.showingResultCard)
            }
        }
        .onAppear {
            viewModel.budgetViewModel = budgetViewModel
            viewModel.startCamera()
        }
        .onDisappear {
            viewModel.stopCamera()
        }
        .alert("Camera Access Required", isPresented: $viewModel.showingPermissionAlert) {
            Button("Settings") {
                if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settingsUrl)
                }
            }
            Button("Cancel", role: .cancel) {
                dismiss()
            }
        } message: {
            Text("Penny needs camera access to scan items for affordability checking. Please enable camera access in Settings.")
        }
    }
}

// MARK: - Affordability Result Card

struct AffordabilityResultCard: View {
    let result: AffordabilityResult
    let budgetViewModel: BudgetViewModel
    let onDismiss: () -> Void
    @State private var showingAddTransaction = false
    
    var body: some View {
        VStack(spacing: 20) {
            // Main affordability indicator
            VStack(spacing: 12) {
                // Affordability status
                HStack {
                    Image(systemName: result.canAfford ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .font(.title)
                        .foregroundColor(result.canAfford ? .green : .red)
                    
                    VStack(alignment: .leading) {
                        Text(result.canAfford ? "You can afford this!" : "Over budget")
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(result.canAfford ? .green : .red)
                        
                        Text("$\(result.estimatedPrice, specifier: "%.2f") • \(result.detectedCategory.rawValue)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
                
                // AI Reasoning
                Text(result.aiReasoning)
                    .font(.body)
                    .multilineTextAlignment(.leading)
                    .padding(.horizontal)
            }
            
            // Budget Impact Details
            VStack(alignment: .leading, spacing: 8) {
                Text("Budget Impact")
                    .font(.headline)
                
                HStack {
                    VStack(alignment: .leading) {
                        Text("Category Remaining")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("$\(result.budgetImpact.categoryBudgetRemaining, specifier: "%.0f")")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing) {
                        Text("Monthly Remaining")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("$\(result.budgetImpact.remainingMonthlyBudget, specifier: "%.0f")")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(8)
            
            // Action buttons
            HStack(spacing: 12) {
                Button("Dismiss") {
                    onDismiss()
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(.systemGray5))
                .foregroundColor(.primary)
                .cornerRadius(8)
                
                if result.canAfford {
                    Button("Add to Budget") {
                        showingAddTransaction = true
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .padding()
        .sheet(isPresented: $showingAddTransaction) {
            AddTransactionView(
                isIncome: false,
                viewModel: budgetViewModel,
                prefilledAmount: result.estimatedPrice,
                prefilledCategory: result.detectedCategory
            )
        }
    }
}

// MARK: - Camera Preview View

struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: UIScreen.main.bounds)
        
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.frame = view.frame
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        // Update preview layer frame if needed
        if let previewLayer = uiView.layer.sublayers?.first as? AVCaptureVideoPreviewLayer {
            previewLayer.frame = uiView.bounds
        }
    }
}

// MARK: - Camera Affordability ViewModel

class CameraAffordabilityViewModel: NSObject, ObservableObject {
    @Published var isProcessing = false
    @Published var showingPermissionAlert = false
    @Published var currentAffordabilityResult: AffordabilityResult?
    @Published var showingResultCard = false
    
    let captureSession = AVCaptureSession()
    private var videoOutput = AVCaptureVideoDataOutput()
    private let sessionQueue = DispatchQueue(label: "camera.session.queue")
    private let visionProcessor = VisionProcessor()
    private let priceEstimationEngine = PriceEstimationEngine()
    
    // Integration with existing budget system
    var budgetViewModel: BudgetViewModel?
    
    override init() {
        super.init()
        setupCamera()
        visionProcessor.delegate = self
    }
    
    private func setupCamera() {
        sessionQueue.async { [weak self] in
            self?.configureCaptureSession()
        }
    }
    
    private func configureCaptureSession() {
        captureSession.beginConfiguration()
        
        // Configure session preset
        captureSession.sessionPreset = .photo
        
        // Add camera input
        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let cameraInput = try? AVCaptureDeviceInput(device: camera) else {
            DispatchQueue.main.async {
                self.showingPermissionAlert = true
            }
            captureSession.commitConfiguration()
            return
        }
        
        if captureSession.canAddInput(cameraInput) {
            captureSession.addInput(cameraInput)
        }
        
        // Add video output
        if captureSession.canAddOutput(videoOutput) {
            captureSession.addOutput(videoOutput)
            videoOutput.setSampleBufferDelegate(self, queue: sessionQueue)
        }
        
        captureSession.commitConfiguration()
    }
    
    func startCamera() {
        checkCameraPermission { [weak self] granted in
            if granted {
                self?.sessionQueue.async {
                    self?.captureSession.startRunning()
                }
            } else {
                DispatchQueue.main.async {
                    self?.showingPermissionAlert = true
                }
            }
        }
    }
    
    func stopCamera() {
        sessionQueue.async { [weak self] in
            self?.captureSession.stopRunning()
        }
    }
    
    private func checkCameraPermission(completion: @escaping (Bool) -> Void) {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            completion(true)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    completion(granted)
                }
            }
        case .denied, .restricted:
            completion(false)
        @unknown default:
            completion(false)
        }
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

extension CameraAffordabilityViewModel: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        // Process frame with VisionKit
        visionProcessor.processFrame(pixelBuffer)
    }
}

// MARK: - Vision Processor Delegate

extension CameraAffordabilityViewModel: VisionProcessorDelegate {
    func visionProcessor(_ processor: VisionProcessor, didDetectObject object: DetectedObject) {
        DispatchQueue.main.async {
            self.isProcessing = true
            
            // Estimate price for detected object
            let estimatedPrice = self.priceEstimationEngine.estimatePrice(for: object)
            
            // Calculate affordability using existing budget system
            if let budgetViewModel = self.budgetViewModel {
                let affordabilityResult = budgetViewModel.calculateAffordability(for: object, estimatedPrice: estimatedPrice)
                
                self.currentAffordabilityResult = affordabilityResult
                self.showingResultCard = true
                
                // Haptic feedback
                let impactFeedback = UIImpactFeedbackGenerator(style: affordabilityResult.canAfford ? .light : .heavy)
                impactFeedback.impactOccurred()
            }
            
            self.isProcessing = false
        }
    }
    
    func visionProcessor(_ processor: VisionProcessor, didFailWithError error: Error) {
        DispatchQueue.main.async {
            self.isProcessing = false
            print("Vision processing error: \(error.localizedDescription)")
        }
    }
}

#Preview {
    CameraAffordabilityView()
}