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
        }
        .onAppear {
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
    
    let captureSession = AVCaptureSession()
    private var videoOutput = AVCaptureVideoDataOutput()
    private let sessionQueue = DispatchQueue(label: "camera.session.queue")
    
    override init() {
        super.init()
        setupCamera()
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
        // This is where we'll process frames for object detection
        // For now, we'll just indicate processing status
        DispatchQueue.main.async {
            // Simulate processing
            if !self.isProcessing {
                self.isProcessing = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    self.isProcessing = false
                }
            }
        }
    }
}

#Preview {
    CameraAffordabilityView()
}