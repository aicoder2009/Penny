//
//  VisionProcessor.swift
//  Penny
//
//  Created by Kiro on 8/17/25.
//

import Foundation
import Vision
import AVFoundation
import CoreML
import MLCompute

// MARK: - Vision Processor

class VisionProcessor: NSObject {
    weak var delegate: VisionProcessorDelegate?
    
    private var requests: [VNRequest] = []
    private let processingQueue = DispatchQueue(label: "vision.processing.queue", qos: .userInitiated)
    private let foundationModelsProcessor = AppleFoundationModelsProcessor()
    
    override init() {
        super.init()
        setupVisionRequests()
        setupFoundationModels()
    }
    
    private func setupFoundationModels() {
        foundationModelsProcessor.initialize()
    }
    
    private func setupVisionRequests() {
        // Set up object detection request
        let objectDetectionRequest = VNDetectRectanglesRequest { [weak self] request, error in
            self?.handleObjectDetection(request: request, error: error)
        }
        
        objectDetectionRequest.minimumAspectRatio = 0.3
        objectDetectionRequest.maximumAspectRatio = 3.0
        objectDetectionRequest.minimumSize = 0.1
        objectDetectionRequest.maximumObservations = 5
        
        requests = [objectDetectionRequest]
    }
    
    func processFrame(_ pixelBuffer: CVPixelBuffer) {
        processingQueue.async { [weak self] in
            guard let self = self else { return }
            
            let imageRequestHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: [:])
            
            do {
                try imageRequestHandler.perform(self.requests)
            } catch {
                DispatchQueue.main.async {
                    self.delegate?.visionProcessor(self, didFailWithError: error)
                }
            }
        }
    }
    
    private func handleObjectDetection(request: VNRequest, error: Error?) {
        if let error = error {
            DispatchQueue.main.async {
                self.delegate?.visionProcessor(self, didFailWithError: error)
            }
            return
        }
        
        guard let observations = request.results as? [VNRectangleObservation] else {
            return
        }
        
        // Process detected rectangles and classify them
        let detectedObjects = observations.compactMap { observation -> DetectedObject? in
            // For now, we'll use a simple heuristic to classify objects
            // This will be enhanced with proper ML models later
            let category = classifyObject(from: observation)
            let confidence = Float(observation.confidence)
            
            // Only return objects with reasonable confidence
            guard confidence > 0.3 else { return nil }
            
            let detectedObject = DetectedObject(
                category: category,
                confidence: confidence * category.detectionConfidenceMultiplier,
                boundingBox: observation.boundingBox
            )
            
            // Enhance with Apple Foundation Models (foundation setup)
            return foundationModelsProcessor.enhanceClassification(for: detectedObject)
        }
        
        // Return the most confident detection
        if let bestDetection = detectedObjects.max(by: { $0.confidence < $1.confidence }) {
            DispatchQueue.main.async {
                self.delegate?.visionProcessor(self, didDetectObject: bestDetection)
            }
        }
    }
    
    private func classifyObject(from observation: VNRectangleObservation) -> Category {
        // Simple heuristic classification based on bounding box properties
        // This is a placeholder that will be replaced with proper ML classification
        
        let boundingBox = observation.boundingBox
        let aspectRatio = boundingBox.width / boundingBox.height
        let area = boundingBox.width * boundingBox.height
        
        // Basic heuristics for object classification
        if aspectRatio > 1.5 && area < 0.3 {
            // Wide, small objects might be food items
            return .food
        } else if aspectRatio < 0.7 && area > 0.2 {
            // Tall, larger objects might be shopping items
            return .shopping
        } else if area < 0.1 {
            // Very small objects might be entertainment items (like tickets)
            return .entertainment
        } else if aspectRatio > 2.0 {
            // Very wide objects might be bills or documents
            return .bills
        } else {
            // Default to other for unclassified objects
            return .other
        }
    }
}

// MARK: - Vision Processor Delegate

protocol VisionProcessorDelegate: AnyObject {
    func visionProcessor(_ processor: VisionProcessor, didDetectObject object: DetectedObject)
    func visionProcessor(_ processor: VisionProcessor, didFailWithError error: Error)
}

// MARK: - Apple Foundation Models Integration

/// Handles Apple Foundation Models integration for on-device AI processing
/// This class provides the foundation for future AI-powered affordability analysis
class AppleFoundationModelsProcessor {
    
    /// Indicates if Apple Foundation Models are available on this device
    /// Currently returns false as we're setting up the foundation
    var isAvailable: Bool {
        // TODO: Implement actual Apple Foundation Models availability check
        // This will be enhanced in future tasks when we integrate the actual models
        return false
    }
    
    /// Prepares the Foundation Models processor for use
    /// Sets up the necessary configurations for on-device AI processing
    func initialize() {
        // TODO: Initialize Apple Foundation Models
        // This will be implemented in task 4 when we integrate the actual models
        print("Apple Foundation Models processor initialized (foundation setup)")
    }
    
    /// Processes detected objects using Apple Foundation Models for enhanced classification
    /// - Parameter detectedObject: The object detected by VisionKit
    /// - Returns: Enhanced classification with AI reasoning (placeholder for now)
    func enhanceClassification(for detectedObject: DetectedObject) -> DetectedObject {
        // TODO: Implement actual Apple Foundation Models processing
        // For now, return the original object as this is foundation setup
        print("Foundation Models processing placeholder - object: \(detectedObject.category)")
        return detectedObject
    }
    
    /// Generates AI-powered affordability reasoning using Foundation Models
    /// - Parameters:
    ///   - object: The detected object
    ///   - canAfford: Whether the user can afford the item
    /// - Returns: Natural language explanation (placeholder for now)
    func generateAffordabilityReasoning(for object: DetectedObject, canAfford: Bool) -> String {
        // TODO: Implement actual Apple Foundation Models reasoning
        // This is foundation setup - actual AI reasoning will be added in task 4
        let affordabilityText = canAfford ? "affordable" : "not affordable"
        return "Based on your budget analysis, this \(object.category.rawValue.lowercased()) item is \(affordabilityText)."
    }
}

// MARK: - Price Estimation Engine

class PriceEstimationEngine {
    
    /// Estimate price for a detected object using category-based heuristics
    /// This will be enhanced with Apple Foundation Models later
    func estimatePrice(for detectedObject: DetectedObject) -> Double {
        let category = detectedObject.category
        let priceRange = category.typicalPriceRange
        let confidence = detectedObject.confidence
        
        // Use confidence to adjust within the price range
        // Higher confidence objects get prices closer to the middle of the range
        // Lower confidence objects get more conservative (lower) estimates
        
        let confidenceAdjustment = Double(confidence)
        let rangeMidpoint = (priceRange.lowerBound + priceRange.upperBound) / 2.0
        let rangeSpread = priceRange.upperBound - priceRange.lowerBound
        
        // Adjust price based on confidence
        let estimatedPrice = rangeMidpoint + (confidenceAdjustment - 0.5) * rangeSpread * 0.3
        
        // Ensure the price stays within the valid range
        return max(priceRange.lowerBound, min(priceRange.upperBound, estimatedPrice))
    }
    
    /// Generate a confidence score for the price estimate
    func getPriceConfidence(for detectedObject: DetectedObject) -> Float {
        // Base confidence on object detection confidence and category reliability
        let baseConfidence = detectedObject.confidence
        let categoryReliability = getCategoryPriceReliability(detectedObject.category)
        
        return min(1.0, baseConfidence * categoryReliability)
    }
    
    private func getCategoryPriceReliability(_ category: Category) -> Float {
        switch category {
        case .food:
            return 0.8 // Food prices are relatively predictable
        case .shopping:
            return 0.6 // Shopping items have wide price variation
        case .transport:
            return 0.9 // Transport costs are fairly standard
        case .entertainment:
            return 0.7 // Entertainment prices vary but are somewhat predictable
        case .bills:
            return 0.5 // Bills are hard to estimate from visual appearance
        case .other:
            return 0.4 // Other items have the highest uncertainty
        }
    }
}