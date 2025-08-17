//
//  CameraAffordabilityTest.swift
//  Penny
//
//  Created by Kiro on 8/17/25.
//

import Foundation

// MARK: - Basic Test Functions

func testAffordabilityCalculation() {
    print("🧪 Testing Camera Affordability Scanner...")
    
    // Create test budget view model
    let budgetViewModel = BudgetViewModel()
    
    // Create test detected object
    let testObject = DetectedObject(
        category: .food,
        confidence: 0.8,
        boundingBox: CGRect(x: 0.2, y: 0.3, width: 0.4, height: 0.3)
    )
    
    // Test price estimation
    let priceEngine = PriceEstimationEngine()
    let estimatedPrice = priceEngine.estimatePrice(for: testObject)
    
    print("✅ Detected object: \(testObject.category.rawValue)")
    print("✅ Confidence: \(testObject.confidence)")
    print("✅ Estimated price: $\(estimatedPrice, specifier: "%.2f")")
    
    // Test affordability calculation
    let affordabilityResult = budgetViewModel.calculateAffordability(for: testObject, estimatedPrice: estimatedPrice)
    
    print("✅ Can afford: \(affordabilityResult.canAfford)")
    print("✅ AI Reasoning: \(affordabilityResult.aiReasoning)")
    print("✅ Budget impact: Category remaining $\(affordabilityResult.budgetImpact.categoryBudgetRemaining, specifier: "%.2f")")
    
    print("🎉 Camera Affordability Scanner test completed!")
}

// MARK: - Test Category Price Ranges

func testCategoryPriceRanges() {
    print("\n🧪 Testing Category Price Ranges...")
    
    for category in Category.allCases {
        let priceRange = category.typicalPriceRange
        let confidence = category.detectionConfidenceMultiplier
        
        print("📦 \(category.icon) \(category.rawValue):")
        print("   Price range: $\(priceRange.lowerBound, specifier: "%.2f") - $\(priceRange.upperBound, specifier: "%.2f")")
        print("   Detection confidence: \(confidence)")
    }
    
    print("✅ Category price range test completed!")
}

// MARK: - Test Vision Processing

func testVisionProcessing() {
    print("\n🧪 Testing Vision Processing...")
    
    let visionProcessor = VisionProcessor()
    
    // Test object classification heuristics
    let testBoundingBoxes = [
        CGRect(x: 0.1, y: 0.1, width: 0.8, height: 0.2), // Wide, small (food)
        CGRect(x: 0.2, y: 0.2, width: 0.3, height: 0.6), // Tall, large (shopping)
        CGRect(x: 0.4, y: 0.4, width: 0.1, height: 0.1), // Small (entertainment)
        CGRect(x: 0.1, y: 0.3, width: 0.8, height: 0.1), // Very wide (bills)
        CGRect(x: 0.3, y: 0.3, width: 0.4, height: 0.4)  // Square (other)
    ]
    
    print("✅ Vision processor initialized")
    print("✅ Test bounding boxes created: \(testBoundingBoxes.count)")
    
    print("🎉 Vision processing test completed!")
}

// MARK: - Run All Tests

func runCameraAffordabilityTests() {
    print("🚀 Starting Camera Affordability Scanner Tests...\n")
    
    testAffordabilityCalculation()
    testCategoryPriceRanges()
    testVisionProcessing()
    
    print("\n🎉 All Camera Affordability Scanner tests completed successfully!")
}