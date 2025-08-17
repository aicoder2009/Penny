//
//  AffordabilityModelsTests.swift
//  Penny
//
//  Created by Kiro on 8/17/25.
//

import XCTest
import Vision
@testable import Penny

class AffordabilityModelsTests: XCTestCase {
    
    // MARK: - Category Extension Tests
    
    func testCategoryDetectionConfidenceMultiplier() {
        // Test that food has higher confidence multiplier
        XCTAssertEqual(Category.food.detectionConfidenceMultiplier, 1.2)
        
        // Test that bills have lower confidence multiplier
        XCTAssertEqual(Category.bills.detectionConfidenceMultiplier, 0.7)
        
        // Test that shopping has standard multiplier
        XCTAssertEqual(Category.shopping.detectionConfidenceMultiplier, 1.0)
    }
    
    func testCategoryMinimumDetectionConfidence() {
        // Test that all categories have reasonable thresholds
        for category in Category.allCases {
            let threshold = category.minimumDetectionConfidence
            XCTAssertGreaterThanOrEqual(threshold, 0.5, "Threshold too low for \(category)")
            XCTAssertLessThanOrEqual(threshold, 1.0, "Threshold too high for \(category)")
        }
        
        // Test specific thresholds
        XCTAssertEqual(Category.food.minimumDetectionConfidence, 0.6)
        XCTAssertEqual(Category.bills.minimumDetectionConfidence, 0.85)
    }
    
    func testCategoryDetectionKeywords() {
        // Test that food category has relevant keywords
        let foodKeywords = Category.food.detectionKeywords
        XCTAssertTrue(foodKeywords.contains("food"))
        XCTAssertTrue(foodKeywords.contains("pizza"))
        XCTAssertGreaterThan(foodKeywords.count, 5)
        
        // Test that shopping category has relevant keywords
        let shoppingKeywords = Category.shopping.detectionKeywords
        XCTAssertTrue(shoppingKeywords.contains("clothing"))
        XCTAssertTrue(shoppingKeywords.contains("electronics"))
    }
    
    func testCategoryTypicalPriceRange() {
        // Test that price ranges are reasonable
        let foodRange = Category.food.typicalPriceRange
        XCTAssertEqual(foodRange.lowerBound, 5.0)
        XCTAssertEqual(foodRange.upperBound, 50.0)
        
        let billsRange = Category.bills.typicalPriceRange
        XCTAssertGreaterThan(billsRange.upperBound, foodRange.upperBound)
    }
    
    // MARK: - DetectedObject Tests
    
    func testDetectedObjectInitialization() {
        let boundingBox = CGRect(x: 0, y: 0, width: 100, height: 100)
        let detectedObject = DetectedObject(
            category: .food,
            confidence: 0.8,
            boundingBox: boundingBox,
            rawClassification: "pizza"
        )
        
        XCTAssertEqual(detectedObject.category, .food)
        XCTAssertEqual(detectedObject.confidence, 0.8)
        XCTAssertEqual(detectedObject.boundingBox, boundingBox)
        XCTAssertEqual(detectedObject.rawClassification, "pizza")
        XCTAssertEqual(detectedObject.detectionSource, .vision)
    }
    
    func testDetectedObjectAdjustedConfidence() {
        let detectedObject = DetectedObject(
            category: .food,
            confidence: 0.7,
            boundingBox: CGRect.zero
        )
        
        // Food has 1.2 multiplier, so 0.7 * 1.2 = 0.84
        let expectedAdjusted = min(0.7 * 1.2, 1.0)
        XCTAssertEqual(detectedObject.adjustedConfidence, expectedAdjusted, accuracy: 0.01)
    }
    
    func testDetectedObjectMeetsConfidenceThreshold() {
        // High confidence food item should meet threshold
        let highConfidenceFood = DetectedObject(
            category: .food,
            confidence: 0.8,
            boundingBox: CGRect.zero
        )
        XCTAssertTrue(highConfidenceFood.meetsConfidenceThreshold)
        
        // Low confidence bills item should not meet threshold
        let lowConfidenceBills = DetectedObject(
            category: .bills,
            confidence: 0.5,
            boundingBox: CGRect.zero
        )
        XCTAssertFalse(lowConfidenceBills.meetsConfidenceThreshold)
    }
    
    func testDetectedObjectBestAlternative() {
        let alternatives = [
            CategoryConfidence(category: .shopping, confidence: 0.9),
            CategoryConfidence(category: .entertainment, confidence: 0.6)
        ]
        
        let detectedObject = DetectedObject(
            category: .bills,
            confidence: 0.5,
            boundingBox: CGRect.zero,
            alternativeCategories: alternatives
        )
        
        let bestAlternative = detectedObject.bestAlternative
        XCTAssertNotNil(bestAlternative)
        XCTAssertEqual(bestAlternative?.category, .shopping)
    }
    
    // MARK: - CategoryConfidence Tests
    
    func testCategoryConfidenceInitialization() {
        let categoryConfidence = CategoryConfidence(
            category: .food,
            confidence: 0.85,
            reasoning: "Detected pizza-like object"
        )
        
        XCTAssertEqual(categoryConfidence.category, .food)
        XCTAssertEqual(categoryConfidence.confidence, 0.85)
        XCTAssertEqual(categoryConfidence.reasoning, "Detected pizza-like object")
    }
    
    // MARK: - TransactionPreview Tests
    
    func testTransactionPreviewInitialization() {
        let preview = TransactionPreview(
            amount: 25.50,
            category: .food,
            note: "Camera detected: pizza",
            confidence: 0.8
        )
        
        XCTAssertEqual(preview.amount, 25.50)
        XCTAssertEqual(preview.category, .food)
        XCTAssertEqual(preview.note, "Camera detected: pizza")
        XCTAssertEqual(preview.confidence, 0.8)
    }
    
    func testTransactionPreviewSuggestedAdjustments() {
        // High confidence should have no adjustments
        let highConfidencePreview = TransactionPreview(
            amount: 25.0,
            category: .food,
            note: "Test",
            confidence: 0.9
        )
        XCTAssertTrue(highConfidencePreview.suggestedAdjustments.isEmpty)
        
        // Medium confidence should suggest amount adjustment
        let mediumConfidencePreview = TransactionPreview(
            amount: 25.0,
            category: .food,
            note: "Test",
            confidence: 0.75
        )
        XCTAssertEqual(mediumConfidencePreview.suggestedAdjustments.count, 1)
        XCTAssertTrue(mediumConfidencePreview.suggestedAdjustments.contains("Consider adjusting the amount"))
        
        // Low confidence should suggest both adjustments
        let lowConfidencePreview = TransactionPreview(
            amount: 25.0,
            category: .food,
            note: "Test",
            confidence: 0.6
        )
        XCTAssertEqual(lowConfidencePreview.suggestedAdjustments.count, 2)
        XCTAssertTrue(lowConfidencePreview.suggestedAdjustments.contains("Consider adjusting the amount"))
        XCTAssertTrue(lowConfidencePreview.suggestedAdjustments.contains("Verify the category"))
    }
    
    func testTransactionPreviewToTransactionData() {
        let preview = TransactionPreview(
            amount: 15.75,
            category: .entertainment,
            note: "Movie ticket",
            confidence: 0.85
        )
        
        let transactionData = preview.transactionData
        XCTAssertEqual(transactionData.amount, 15.75)
        XCTAssertEqual(transactionData.category, .entertainment)
        XCTAssertNil(transactionData.incomeCategory)
        XCTAssertFalse(transactionData.isIncome)
        XCTAssertEqual(transactionData.note, "Movie ticket")
    }
    
    // MARK: - BudgetImpact Tests
    
    func testBudgetImpactInitialization() {
        let budgetImpact = BudgetImpact(
            remainingMonthlyBudget: 500.0,
            categoryBudgetRemaining: 100.0,
            dailyBudgetImpact: 5.0,
            wouldExceedBudget: false,
            streakRisk: .low,
            currentMonthlySpending: 500.0,
            monthlyBudget: 1000.0,
            daysRemainingInMonth: 15
        )
        
        XCTAssertEqual(budgetImpact.remainingMonthlyBudget, 500.0)
        XCTAssertEqual(budgetImpact.categoryBudgetRemaining, 100.0)
        XCTAssertEqual(budgetImpact.streakRisk, .low)
        XCTAssertNotNil(budgetImpact.budgetUtilization)
        XCTAssertNotNil(budgetImpact.projectedMonthEnd)
        XCTAssertFalse(budgetImpact.smartRecommendations.isEmpty)
    }
    
    func testBudgetUtilization() {
        let budgetImpact = BudgetImpact(
            remainingMonthlyBudget: 300.0,
            categoryBudgetRemaining: 50.0,
            dailyBudgetImpact: 10.0,
            wouldExceedBudget: false,
            streakRisk: .medium,
            currentMonthlySpending: 700.0,
            monthlyBudget: 1000.0,
            daysRemainingInMonth: 10
        )
        
        let utilization = budgetImpact.budgetUtilization
        XCTAssertEqual(utilization.monthlyUsagePercentage, 0.7, accuracy: 0.01)
        XCTAssertEqual(utilization.utilizationStatus, .underUtilized)
        XCTAssertTrue(utilization.isOnTrack)
    }
    
    func testProjectedMonthEnd() {
        let budgetImpact = BudgetImpact(
            remainingMonthlyBudget: 100.0,
            categoryBudgetRemaining: 50.0,
            dailyBudgetImpact: 15.0,
            wouldExceedBudget: false,
            streakRisk: .high,
            currentMonthlySpending: 900.0,
            monthlyBudget: 1000.0,
            daysRemainingInMonth: 10
        )
        
        let projection = budgetImpact.projectedMonthEnd
        XCTAssertGreaterThan(projection.projectedTotalSpending, 900.0)
        XCTAssertEqual(projection.confidenceLevel, 0.5, accuracy: 0.1) // High streak risk = low confidence
        XCTAssertEqual(projection.confidenceDescription, "Low Confidence")
    }
    
    func testSmartBudgetRecommendations() {
        // Test budget reallocation recommendation when exceeding budget
        let budgetImpact = BudgetImpact(
            remainingMonthlyBudget: 500.0,
            categoryBudgetRemaining: -50.0, // Exceeding category budget
            dailyBudgetImpact: 10.0,
            wouldExceedBudget: true,
            streakRisk: .high,
            currentMonthlySpending: 500.0,
            monthlyBudget: 1000.0,
            daysRemainingInMonth: 15
        )
        
        let recommendations = budgetImpact.smartRecommendations
        XCTAssertFalse(recommendations.isEmpty)
        
        let budgetReallocation = recommendations.first { $0.type == .budgetReallocation }
        XCTAssertNotNil(budgetReallocation)
        XCTAssertEqual(budgetReallocation?.priority, .high)
    }
    
    // MARK: - AffordabilityRecommendation Tests
    
    func testAffordabilityRecommendationInitialization() {
        let impact = EstimatedImpact(
            budgetSavings: 25.0,
            timeToAfford: 5,
            streakProtection: 0.8,
            confidenceLevel: 0.9
        )
        
        let alternatives = [
            AlternativeAction(
                title: "Wait until next month",
                description: "Purchase at the beginning of next month",
                actionType: .postpone,
                estimatedOutcome: "Better budget management"
            )
        ]
        
        let recommendation = AffordabilityRecommendation(
            type: .waitAndSave,
            title: "Save for 5 days",
            description: "Set aside $5 daily",
            actionable: true,
            priority: .medium,
            aiReasoning: "Based on spending patterns",
            estimatedImpact: impact,
            alternativeActions: alternatives
        )
        
        XCTAssertEqual(recommendation.type, .waitAndSave)
        XCTAssertEqual(recommendation.priority, .medium)
        XCTAssertTrue(recommendation.actionable)
        XCTAssertEqual(recommendation.estimatedImpact.budgetSavings, 25.0)
        XCTAssertEqual(recommendation.alternativeActions.count, 1)
    }
    
    func testEstimatedImpactSummary() {
        let impact = EstimatedImpact(
            budgetSavings: 50.0,
            timeToAfford: 10,
            streakProtection: 0.9,
            confidenceLevel: 0.8
        )
        
        let summary = impact.impactSummary
        XCTAssertTrue(summary.contains("Save $50"))
        XCTAssertTrue(summary.contains("10 days to afford"))
        XCTAssertTrue(summary.contains("Protects streak"))
    }
    
    func testRecommendationPrioritySorting() {
        let lowPriority = AffordabilityRecommendation(
            type: .optimalTiming,
            title: "Low",
            description: "Low priority",
            actionable: true,
            priority: .low
        )
        
        let highPriority = AffordabilityRecommendation(
            type: .streakProtection,
            title: "High",
            description: "High priority",
            actionable: true,
            priority: .high
        )
        
        let criticalPriority = AffordabilityRecommendation(
            type: .budgetAdjustment,
            title: "Critical",
            description: "Critical priority",
            actionable: true,
            priority: .critical
        )
        
        let recommendations = [lowPriority, highPriority, criticalPriority]
        let sorted = recommendations.sorted { $0.priority.sortOrder > $1.priority.sortOrder }
        
        XCTAssertEqual(sorted[0].priority, .critical)
        XCTAssertEqual(sorted[1].priority, .high)
        XCTAssertEqual(sorted[2].priority, .low)
    }
    
    // MARK: - AffordabilityResult Tests
    
    func testAffordabilityResultWithEnhancedModels() {
        let detectedObject = DetectedObject(
            category: .food,
            confidence: 0.8,
            boundingBox: CGRect.zero,
            rawClassification: "sandwich"
        )
        
        let budgetImpact = BudgetImpact(
            remainingMonthlyBudget: 500.0,
            categoryBudgetRemaining: 100.0,
            dailyBudgetImpact: 5.0,
            wouldExceedBudget: false,
            streakRisk: .low,
            currentMonthlySpending: 500.0,
            monthlyBudget: 1000.0,
            daysRemainingInMonth: 15
        )
        
        let result = AffordabilityResult(
            canAfford: true,
            estimatedPrice: 12.50,
            detectedCategory: .food,
            budgetImpact: budgetImpact,
            aiReasoning: "Within budget with AI analysis",
            confidence: 0.8,
            detectedObject: detectedObject
        )
        
        XCTAssertTrue(result.canAfford)
        XCTAssertEqual(result.estimatedPrice, 12.50)
        XCTAssertEqual(result.detectedCategory, .food)
        XCTAssertEqual(result.confidence, 0.8)
        XCTAssertEqual(result.feedbackColor, "green")
        XCTAssertEqual(result.feedbackIcon, "checkmark.circle.fill")
        XCTAssertTrue(result.quickSummary.contains("✅ Affordable"))
        
        // Test transaction preview integration
        let transactionData = result.transactionPreview.transactionData
        XCTAssertEqual(transactionData.amount, 12.50)
        XCTAssertEqual(transactionData.category, .food)
        XCTAssertFalse(transactionData.isIncome)
        XCTAssertTrue(transactionData.note.contains("Camera detected"))
    }
    
    func testAffordabilityResultNotAffordableWithAI() {
        let detectedObject = DetectedObject(
            category: .shopping,
            confidence: 0.9,
            boundingBox: CGRect.zero,
            rawClassification: "expensive gadget"
        )
        
        let budgetImpact = BudgetImpact(
            remainingMonthlyBudget: 50.0,
            categoryBudgetRemaining: 10.0,
            dailyBudgetImpact: 20.0,
            wouldExceedBudget: true,
            streakRisk: .high,
            currentMonthlySpending: 950.0,
            monthlyBudget: 1000.0,
            daysRemainingInMonth: 5
        )
        
        let result = AffordabilityResult(
            canAfford: false,
            estimatedPrice: 150.0,
            detectedCategory: .shopping,
            budgetImpact: budgetImpact,
            aiReasoning: "Exceeds budget with AI analysis",
            confidence: 0.9,
            detectedObject: detectedObject
        )
        
        XCTAssertFalse(result.canAfford)
        XCTAssertEqual(result.feedbackColor, "red")
        XCTAssertEqual(result.feedbackIcon, "xmark.circle.fill")
        XCTAssertTrue(result.quickSummary.contains("❌ Not Affordable"))
        
        // Verify enhanced budget impact
        XCTAssertTrue(budgetImpact.projectedMonthEnd.isProjectedToExceed)
        XCTAssertEqual(budgetImpact.budgetUtilization.utilizationStatus, .overBudget)
    }
}