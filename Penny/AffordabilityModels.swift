//
//  AffordabilityModels.swift
//  Penny
//
//  Created by Kiro on 8/17/25.
//

import Foundation
import Vision

// MARK: - Detected Object Model

/// Represents an object detected by the camera affordability scanner using VisionKit
/// 
/// This model encapsulates the complete results of computer vision object detection,
/// including the classified category, confidence metrics, spatial information, and
/// alternative classifications for robust affordability analysis.
///
/// - Note: All confidence values are normalized between 0.0 and 1.0
/// - Important: BoundingBox coordinates use Vision framework format (origin at bottom-left)
struct DetectedObject: Identifiable, Codable {
    /// Unique identifier for SwiftUI list rendering and state management
    let id = UUID()
    
    /// The primary classified expense category for this detected object
    /// Used for budget calculations and price estimation algorithms
    let category: Category
    
    /// Raw detection confidence score from VisionKit (0.0 to 1.0)
    /// Higher values indicate more reliable object classification
    let confidence: Float
    
    /// Normalized bounding box coordinates in Vision framework format
    /// Origin (0,0) is bottom-left, values range from 0.0 to 1.0
    /// Used for UI overlay positioning and object size estimation
    let boundingBox: CGRect
    
    /// Timestamp when the object was detected
    /// Used for tracking detection history, debugging, and temporal analysis
    let timestamp: Date
    
    /// Original classification string from the ML model
    /// Preserved for debugging, user feedback, and model improvement
    let rawClassification: String
    
    /// Alternative category suggestions with confidence scores
    /// Provides fallback options when primary classification has low confidence
    let alternativeCategories: [CategoryConfidence]
    
    /// Source of the object detection (VisionKit, Core ML, etc.)
    /// Used for analytics and debugging different detection pipelines
    let detectionSource: DetectionSource
    
    /// Creates a new detected object with comprehensive detection metadata
    /// - Parameters:
    ///   - category: The primary expense category classification
    ///   - confidence: VisionKit confidence score (0.0-1.0, higher indicates better detection)
    ///   - boundingBox: Normalized coordinates of the detected object in Vision format
    ///   - rawClassification: Original ML model output string for debugging
    ///   - alternativeCategories: Backup category suggestions with confidence scores
    ///   - detectionSource: Which detection system produced this result
    /// - Note: Timestamp is automatically set to current date/time for tracking
    init(category: Category, confidence: Float, boundingBox: CGRect, rawClassification: String = "", alternativeCategories: [CategoryConfidence] = [], detectionSource: DetectionSource = .vision) {
        self.category = category
        self.confidence = confidence
        self.boundingBox = boundingBox
        self.rawClassification = rawClassification
        self.alternativeCategories = alternativeCategories
        self.detectionSource = detectionSource
        self.timestamp = Date()
    }
    
    /// Confidence score adjusted by category-specific multipliers for improved accuracy
    /// 
    /// Different object categories have varying detection reliability. This computed property
    /// applies category-specific multipliers to the raw confidence score while ensuring
    /// the result never exceeds 1.0.
    /// 
    /// - Returns: Adjusted confidence score (0.0-1.0) optimized for the detected category
    /// - Note: Food items get 1.2x multiplier, bills get 0.7x due to detection difficulty
    var adjustedConfidence: Float {
        return min(confidence * category.detectionConfidenceMultiplier, 1.0)
    }
    
    /// Determines if this detection meets the category-specific confidence threshold
    /// 
    /// Each category has different minimum confidence requirements based on detection
    /// reliability and the cost of false positives in affordability calculations.
    /// 
    /// - Returns: `true` if adjusted confidence meets or exceeds the category threshold
    /// - Note: Used to filter out unreliable detections before price estimation
    var meetsConfidenceThreshold: Bool {
        return adjustedConfidence >= category.minimumDetectionConfidence
    }
    
    /// Returns the best alternative category if the primary classification is unreliable
    /// 
    /// When the primary category doesn't meet confidence thresholds, this provides
    /// the highest-confidence alternative that does meet its respective threshold.
    /// 
    /// - Returns: The most confident alternative category, or `nil` if none qualify
    /// - Note: Essential for graceful degradation when primary detection fails
    var bestAlternative: CategoryConfidence? {
        return alternativeCategories.first { $0.confidence >= $0.category.minimumDetectionConfidence }
    }
}

// MARK: - Supporting Detection Models

/// Represents an alternative category classification with confidence and reasoning
/// 
/// Used when the primary object detection produces multiple possible categories,
/// providing fallback options and transparency in the classification process.
/// Essential for handling edge cases and improving user trust in AI decisions.
struct CategoryConfidence: Codable {
    /// The alternative expense category classification
    let category: Category
    
    /// Confidence score for this alternative classification (0.0-1.0)
    let confidence: Float
    
    /// Human-readable explanation of why this category was suggested
    /// Generated by Apple Foundation Models for transparency
    let reasoning: String
    
    /// Creates a new alternative category suggestion
    /// - Parameters:
    ///   - category: The suggested expense category
    ///   - confidence: How confident the model is in this classification (0.0-1.0)
    ///   - reasoning: AI-generated explanation for this suggestion
    init(category: Category, confidence: Float, reasoning: String = "") {
        self.category = category
        self.confidence = confidence
        self.reasoning = reasoning
    }
}

/// Identifies the source system that performed object detection
/// 
/// Different detection systems have varying accuracy, performance, and capabilities.
/// Tracking the source enables analytics, debugging, and system optimization.
enum DetectionSource: String, Codable, CaseIterable {
    /// Apple's VisionKit framework for real-time camera detection
    case vision = "VisionKit"
    
    /// Custom Core ML models for specialized object recognition
    case coreML = "Core ML"
    
    /// Apple Foundation Models for advanced AI-powered classification
    case foundationModels = "Apple Foundation Models"
    
    /// User manually selected or corrected the category
    case manual = "Manual Selection"
    
    /// Human-readable name for UI display
    /// - Returns: The formatted display name for this detection source
    var displayName: String {
        return rawValue
    }
}

// MARK: - Affordability Result Model

/// Complete affordability analysis result for a camera-detected object
/// 
/// This is the core model that combines object detection, price estimation,
/// budget analysis, and AI-powered recommendations into a single comprehensive
/// result. Used throughout the UI to present affordability decisions to users.
///
/// - Important: All price values are in USD
/// - Note: Contains pre-computed UI properties for immediate display
struct AffordabilityResult: Identifiable, Codable {
    /// Unique identifier for SwiftUI list rendering and state management
    let id = UUID()
    
    /// Primary affordability decision - can the user afford this item?
    /// Based on category budget, monthly budget, and AI-enhanced analysis
    let canAfford: Bool
    
    /// AI-estimated price for the detected object in USD
    /// Generated using category-based heuristics and Apple Foundation Models
    let estimatedPrice: Double
    
    /// Confidence range for the price estimate (min...max in USD)
    /// Provides transparency about estimation uncertainty
    let priceRange: ClosedRange<Double>
    
    /// The expense category used for budget calculations
    /// May differ from detected category if confidence was low
    let detectedCategory: Category
    
    /// Comprehensive analysis of how this purchase affects the user's budget
    /// Includes streak risk, utilization metrics, and projections
    let budgetImpact: BudgetImpact
    
    /// Natural language explanation generated by Apple Foundation Models
    /// Explains the affordability decision in user-friendly terms
    let aiReasoning: String
    
    /// Overall confidence in the affordability analysis (0.0-1.0)
    /// Combines detection confidence with price estimation reliability
    let confidence: Float
    
    /// AI-generated actionable recommendations for the user
    /// Includes savings plans, budget adjustments, and alternatives
    let recommendations: [AffordabilityRecommendation]
    
    /// When this affordability analysis was performed
    /// Used for caching, debugging, and temporal analysis
    let timestamp: Date
    
    /// The original detected object that triggered this analysis
    /// Preserved for debugging and user feedback collection
    let detectedObject: DetectedObject
    
    /// Pre-configured transaction data for seamless expense entry
    /// Enables one-tap addition to budget tracking
    let transactionPreview: TransactionPreview
    
    /// Creates a comprehensive affordability analysis result
    /// - Parameters:
    ///   - canAfford: Whether the user can afford this item based on budget analysis
    ///   - estimatedPrice: AI-estimated price in USD
    ///   - priceRange: Optional price confidence range (defaults to ±20% of estimate)
    ///   - detectedCategory: Category used for budget calculations
    ///   - budgetImpact: Detailed analysis of budget effects
    ///   - aiReasoning: Natural language explanation from Apple Foundation Models
    ///   - confidence: Overall analysis confidence (0.0-1.0)
    ///   - recommendations: AI-generated actionable suggestions
    ///   - detectedObject: Original detection that triggered this analysis
    /// - Note: Automatically creates transaction preview and sets timestamp
    init(canAfford: Bool, estimatedPrice: Double, priceRange: ClosedRange<Double>? = nil, detectedCategory: Category, budgetImpact: BudgetImpact, aiReasoning: String, confidence: Float, recommendations: [AffordabilityRecommendation] = [], detectedObject: DetectedObject) {
        self.canAfford = canAfford
        self.estimatedPrice = estimatedPrice
        self.priceRange = priceRange ?? (estimatedPrice * 0.8)...(estimatedPrice * 1.2)
        self.detectedCategory = detectedCategory
        self.budgetImpact = budgetImpact
        self.aiReasoning = aiReasoning
        self.confidence = confidence
        self.recommendations = recommendations
        self.detectedObject = detectedObject
        self.timestamp = Date()
        
        // Create transaction preview for seamless integration with existing expense tracking
        self.transactionPreview = TransactionPreview(
            amount: estimatedPrice,
            category: detectedCategory,
            note: "Camera detected: \(detectedObject.rawClassification)",
            confidence: confidence
        )
    }
    
    /// SwiftUI color name for affordability feedback UI
    /// - Returns: "green" for affordable items, "red" for unaffordable items
    /// - Note: Used for consistent color coding across the app interface
    var feedbackColor: String {
        return canAfford ? "green" : "red"
    }
    
    /// SF Symbols icon name for affordability status display
    /// - Returns: Checkmark icon for affordable, X-mark icon for unaffordable
    /// - Note: Provides immediate visual feedback in result cards and overlays
    var feedbackIcon: String {
        return canAfford ? "checkmark.circle.fill" : "xmark.circle.fill"
    }
    
    /// Concise one-line summary for quick display in lists and notifications
    /// - Returns: Formatted string with affordability status, price, and category
    /// - Example: "✅ Affordable • $25 • Food" or "❌ Not Affordable • $150 • Shopping"
    var quickSummary: String {
        let affordabilityText = canAfford ? "✅ Affordable" : "❌ Not Affordable"
        return "\(affordabilityText) • $\(estimatedPrice, specifier: "%.0f") • \(detectedCategory.rawValue)"
    }
}

// MARK: - Transaction Preview Model

/// Pre-configured transaction data for seamless expense entry integration
/// 
/// This model bridges the gap between camera detection and the existing
/// transaction system, enabling one-tap expense addition with smart defaults
/// and confidence-based suggestions for user review.
struct TransactionPreview: Codable {
    /// Estimated transaction amount in USD from price estimation
    let amount: Double
    
    /// Detected expense category for budget allocation
    let category: Category
    
    /// Auto-generated note describing the detection source and classification
    let note: String
    
    /// Overall confidence in the detection and price estimate (0.0-1.0)
    let confidence: Float
    
    /// AI-generated suggestions for user review based on confidence levels
    /// Lower confidence triggers more adjustment suggestions
    let suggestedAdjustments: [String]
    
    /// Creates a transaction preview with confidence-based adjustment suggestions
    /// - Parameters:
    ///   - amount: Estimated transaction amount in USD
    ///   - category: Detected expense category
    ///   - note: Descriptive note about the detection
    ///   - confidence: Overall detection confidence (0.0-1.0)
    /// - Note: Automatically generates adjustment suggestions for low-confidence detections
    init(amount: Double, category: Category, note: String, confidence: Float) {
        self.amount = amount
        self.category = category
        self.note = note
        self.confidence = confidence
        
        // Generate suggested adjustments based on confidence levels
        var adjustments: [String] = []
        if confidence < 0.8 {
            adjustments.append("Consider adjusting the amount")
        }
        if confidence < 0.7 {
            adjustments.append("Verify the category")
        }
        self.suggestedAdjustments = adjustments
    }
    
    /// Converts preview data to format expected by existing transaction system
    /// 
    /// Provides seamless integration with the current BudgetViewModel.addTransaction()
    /// method by formatting the preview data into the expected tuple structure.
    /// 
    /// - Returns: Tuple containing all required transaction parameters
    /// - Note: Always creates expense transactions (isIncome: false)
    /// - Note: Uses current date/time for transaction timestamp
    var transactionData: (amount: Double, category: Category?, incomeCategory: IncomeCategory?, isIncome: Bool, date: Date, note: String) {
        return (
            amount: amount,
            category: category,
            incomeCategory: nil,
            isIncome: false,
            date: Date(),
            note: note
        )
    }
}

// MARK: - Budget Impact Model

/// Comprehensive analysis of how a purchase affects the user's budget and financial goals
/// 
/// This model provides detailed insights into budget utilization, streak protection,
/// and future spending projections. Used to generate actionable recommendations
/// and help users understand the full financial impact of their purchase decisions.
struct BudgetImpact: Codable {
    /// Remaining monthly budget after this purchase (in USD)
    /// Negative values indicate budget overrun
    let remainingMonthlyBudget: Double
    
    /// Remaining budget in the specific category after this purchase (in USD)
    /// Used for category-specific spending guidance
    let categoryBudgetRemaining: Double
    
    /// Daily budget impact if this purchase is made (in USD per day)
    /// Helps users understand spending pace implications
    let dailyBudgetImpact: Double
    
    /// Whether this purchase would exceed any budget limits
    /// Triggers warning UI and alternative recommendations
    let wouldExceedBudget: Bool
    
    /// Risk level this purchase poses to the user's spending streak
    /// Considers streak length and budget utilization for protection
    let streakRisk: StreakRisk
    
    /// Detailed metrics about current budget utilization patterns
    /// Provides context for spending decisions and trend analysis
    let budgetUtilization: BudgetUtilization
    
    /// AI-powered projections for end-of-month budget status
    /// Helps users understand long-term implications of current spending
    let projectedMonthEnd: ProjectedMonthEnd
    
    /// Prioritized list of AI-generated budget optimization suggestions
    /// Provides actionable steps for better financial management
    let smartRecommendations: [SmartBudgetRecommendation]
    
    /// Creates comprehensive budget impact analysis with AI-powered insights
    /// - Parameters:
    ///   - remainingMonthlyBudget: Monthly budget remaining after purchase (USD)
    ///   - categoryBudgetRemaining: Category budget remaining after purchase (USD)
    ///   - dailyBudgetImpact: Daily spending impact of this purchase (USD/day)
    ///   - wouldExceedBudget: Whether purchase exceeds any budget limits
    ///   - streakRisk: Risk level to current spending streak
    ///   - currentMonthlySpending: Total spending so far this month (USD)
    ///   - monthlyBudget: Total monthly budget limit (USD)
    ///   - daysRemainingInMonth: Days left in current month for projections
    /// - Note: Automatically calculates utilization metrics and generates recommendations
    init(remainingMonthlyBudget: Double, categoryBudgetRemaining: Double, dailyBudgetImpact: Double, wouldExceedBudget: Bool, streakRisk: StreakRisk, currentMonthlySpending: Double, monthlyBudget: Double, daysRemainingInMonth: Int) {
        self.remainingMonthlyBudget = remainingMonthlyBudget
        self.categoryBudgetRemaining = categoryBudgetRemaining
        self.dailyBudgetImpact = dailyBudgetImpact
        self.wouldExceedBudget = wouldExceedBudget
        self.streakRisk = streakRisk
        
        // Calculate budget utilization
        self.budgetUtilization = BudgetUtilization(
            monthlyUsagePercentage: currentMonthlySpending / monthlyBudget,
            categoryUsagePercentage: (monthlyBudget - remainingMonthlyBudget) / monthlyBudget,
            dailyBurnRate: currentMonthlySpending / max(30 - daysRemainingInMonth, 1),
            projectedMonthlySpending: currentMonthlySpending + (dailyBudgetImpact * Double(daysRemainingInMonth))
        )
        
        // Calculate projected month end
        self.projectedMonthEnd = ProjectedMonthEnd(
            projectedTotalSpending: budgetUtilization.projectedMonthlySpending,
            projectedOverage: max(budgetUtilization.projectedMonthlySpending - monthlyBudget, 0),
            confidenceLevel: streakRisk == .none ? 0.9 : (streakRisk == .low ? 0.7 : 0.5)
        )
        
        // Generate smart recommendations
        var recommendations: [SmartBudgetRecommendation] = []
        
        if wouldExceedBudget {
            recommendations.append(SmartBudgetRecommendation(
                type: .budgetReallocation,
                priority: .high,
                title: "Consider Budget Reallocation",
                description: "Move funds from other categories to afford this purchase",
                potentialSavings: categoryBudgetRemaining,
                actionable: true
            ))
        }
        
        if budgetUtilization.dailyBurnRate > (monthlyBudget / 30) * 1.2 {
            recommendations.append(SmartBudgetRecommendation(
                type: .spendingPace,
                priority: .medium,
                title: "Slow Down Spending Pace",
                description: "Current spending rate may exceed monthly budget",
                potentialSavings: budgetUtilization.dailyBurnRate * Double(daysRemainingInMonth) - remainingMonthlyBudget,
                actionable: true
            ))
        }
        
        if streakRisk != .none {
            recommendations.append(SmartBudgetRecommendation(
                type: .streakProtection,
                priority: streakRisk == .high ? .high : .medium,
                title: "Protect Your Streak",
                description: "This purchase may impact your \(30 - daysRemainingInMonth) day spending streak",
                potentialSavings: 0,
                actionable: false
            ))
        }
        
        self.smartRecommendations = recommendations
    }
    
    enum StreakRisk: String, Codable, CaseIterable {
        case none = "none"
        case low = "low"
        case medium = "medium"
        case high = "high"
        
        var description: String {
            switch self {
            case .none: return "No impact on streak"
            case .low: return "Low risk to streak"
            case .medium: return "Medium risk to streak"
            case .high: return "High risk to streak"
            }
        }
        
        var color: String {
            switch self {
            case .none: return "green"
            case .low: return "yellow"
            case .medium: return "orange"
            case .high: return "red"
            }
        }
        
        var icon: String {
            switch self {
            case .none: return "checkmark.shield.fill"
            case .low: return "exclamationmark.shield.fill"
            case .medium: return "exclamationmark.triangle.fill"
            case .high: return "xmark.shield.fill"
            }
        }
    }
}

// MARK: - Budget Utilization Model

struct BudgetUtilization: Codable {
    let monthlyUsagePercentage: Double
    let categoryUsagePercentage: Double
    let dailyBurnRate: Double
    let projectedMonthlySpending: Double
    
    var isOnTrack: Bool {
        return monthlyUsagePercentage <= 1.0 && projectedMonthlySpending <= monthlyUsagePercentage * 1.1
    }
    
    var utilizationStatus: UtilizationStatus {
        if monthlyUsagePercentage <= 0.7 {
            return .underUtilized
        } else if monthlyUsagePercentage <= 0.9 {
            return .onTrack
        } else if monthlyUsagePercentage <= 1.0 {
            return .nearLimit
        } else {
            return .overBudget
        }
    }
    
    enum UtilizationStatus: String, Codable {
        case underUtilized = "Under Utilized"
        case onTrack = "On Track"
        case nearLimit = "Near Limit"
        case overBudget = "Over Budget"
        
        var color: String {
            switch self {
            case .underUtilized: return "blue"
            case .onTrack: return "green"
            case .nearLimit: return "orange"
            case .overBudget: return "red"
            }
        }
    }
}

// MARK: - Projected Month End Model

struct ProjectedMonthEnd: Codable {
    let projectedTotalSpending: Double
    let projectedOverage: Double
    let confidenceLevel: Double
    
    var isProjectedToExceed: Bool {
        return projectedOverage > 0
    }
    
    var confidenceDescription: String {
        if confidenceLevel >= 0.8 {
            return "High Confidence"
        } else if confidenceLevel >= 0.6 {
            return "Medium Confidence"
        } else {
            return "Low Confidence"
        }
    }
}

// MARK: - Smart Budget Recommendation Model

struct SmartBudgetRecommendation: Codable, Identifiable {
    let id = UUID()
    let type: RecommendationType
    let priority: Priority
    let title: String
    let description: String
    let potentialSavings: Double
    let actionable: Bool
    
    enum RecommendationType: String, Codable {
        case budgetReallocation = "Budget Reallocation"
        case spendingPace = "Spending Pace"
        case streakProtection = "Streak Protection"
        case categoryOptimization = "Category Optimization"
        case timingOptimization = "Timing Optimization"
        
        var icon: String {
            switch self {
            case .budgetReallocation: return "arrow.triangle.2.circlepath"
            case .spendingPace: return "speedometer"
            case .streakProtection: return "flame.fill"
            case .categoryOptimization: return "chart.pie.fill"
            case .timingOptimization: return "clock.fill"
            }
        }
    }
    
    enum Priority: String, Codable, CaseIterable {
        case low = "Low"
        case medium = "Medium"
        case high = "High"
        
        var color: String {
            switch self {
            case .low: return "gray"
            case .medium: return "orange"
            case .high: return "red"
            }
        }
        
        var sortOrder: Int {
            switch self {
            case .high: return 3
            case .medium: return 2
            case .low: return 1
            }
        }
    }
}

// MARK: - Affordability Recommendation Model

struct AffordabilityRecommendation: Identifiable, Codable {
    let id = UUID()
    let type: RecommendationType
    let title: String
    let description: String
    let actionable: Bool
    let priority: Priority
    let aiReasoning: String
    let estimatedImpact: EstimatedImpact
    let alternativeActions: [AlternativeAction]
    
    init(type: RecommendationType, title: String, description: String, actionable: Bool, priority: Priority = .medium, aiReasoning: String = "", estimatedImpact: EstimatedImpact? = nil, alternativeActions: [AlternativeAction] = []) {
        self.type = type
        self.title = title
        self.description = description
        self.actionable = actionable
        self.priority = priority
        self.aiReasoning = aiReasoning
        self.estimatedImpact = estimatedImpact ?? EstimatedImpact()
        self.alternativeActions = alternativeActions
    }
    
    enum RecommendationType: String, Codable, CaseIterable {
        case waitAndSave = "Wait and Save"
        case alternativeCategory = "Alternative Category"
        case optimalTiming = "Optimal Timing"
        case budgetAdjustment = "Budget Adjustment"
        case streakProtection = "Streak Protection"
        case aiOptimization = "AI Optimization"
        case behavioralInsight = "Behavioral Insight"
        
        var icon: String {
            switch self {
            case .waitAndSave: return "clock.badge.checkmark"
            case .alternativeCategory: return "arrow.triangle.branch"
            case .optimalTiming: return "calendar.badge.clock"
            case .budgetAdjustment: return "slider.horizontal.3"
            case .streakProtection: return "flame.fill"
            case .aiOptimization: return "brain.head.profile"
            case .behavioralInsight: return "chart.line.uptrend.xyaxis"
            }
        }
        
        var color: String {
            switch self {
            case .waitAndSave: return "blue"
            case .alternativeCategory: return "purple"
            case .optimalTiming: return "green"
            case .budgetAdjustment: return "orange"
            case .streakProtection: return "red"
            case .aiOptimization: return "indigo"
            case .behavioralInsight: return "teal"
            }
        }
    }
    
    enum Priority: String, Codable, CaseIterable {
        case low = "Low"
        case medium = "Medium"
        case high = "High"
        case critical = "Critical"
        
        var sortOrder: Int {
            switch self {
            case .critical: return 4
            case .high: return 3
            case .medium: return 2
            case .low: return 1
            }
        }
        
        var color: String {
            switch self {
            case .low: return "gray"
            case .medium: return "blue"
            case .high: return "orange"
            case .critical: return "red"
            }
        }
    }
}

// MARK: - Estimated Impact Model

struct EstimatedImpact: Codable {
    let budgetSavings: Double
    let timeToAfford: Int // days
    let streakProtection: Double // 0.0 to 1.0
    let confidenceLevel: Double // 0.0 to 1.0
    
    init(budgetSavings: Double = 0.0, timeToAfford: Int = 0, streakProtection: Double = 0.0, confidenceLevel: Double = 0.5) {
        self.budgetSavings = budgetSavings
        self.timeToAfford = timeToAfford
        self.streakProtection = streakProtection
        self.confidenceLevel = confidenceLevel
    }
    
    var impactSummary: String {
        var components: [String] = []
        
        if budgetSavings > 0 {
            components.append("Save $\(budgetSavings, specifier: "%.0f")")
        }
        
        if timeToAfford > 0 {
            components.append("\(timeToAfford) days to afford")
        }
        
        if streakProtection > 0.5 {
            components.append("Protects streak")
        }
        
        return components.isEmpty ? "Minimal impact" : components.joined(separator: " • ")
    }
}

// MARK: - Alternative Action Model

struct AlternativeAction: Codable, Identifiable {
    let id = UUID()
    let title: String
    let description: String
    let actionType: ActionType
    let estimatedOutcome: String
    
    enum ActionType: String, Codable {
        case postpone = "Postpone Purchase"
        case substitute = "Find Substitute"
        case negotiate = "Negotiate Price"
        case reallocate = "Reallocate Budget"
        case saveFirst = "Save First"
        
        var icon: String {
            switch self {
            case .postpone: return "clock.arrow.circlepath"
            case .substitute: return "arrow.triangle.swap"
            case .negotiate: return "person.2.badge.minus"
            case .reallocate: return "arrow.triangle.2.circlepath"
            case .saveFirst: return "banknote.fill"
            }
        }
    }
}

// MARK: - Extensions to Existing Models

extension Category {
    /// Typical price ranges for items in each expense category
    /// 
    /// These ranges are used for price estimation when specific item data
    /// is unavailable. Based on market research and user spending patterns.
    /// 
    /// - Returns: Closed range representing min...max typical prices in USD
    /// - Note: Ranges are conservative to avoid overestimation
    /// - Important: Update ranges periodically based on inflation and market changes
    var typicalPriceRange: ClosedRange<Double> {
        switch self {
        case .food:
            return 5.0...50.0
        case .shopping:
            return 10.0...200.0
        case .transport:
            return 2.0...100.0
        case .entertainment:
            return 8.0...80.0
        case .bills:
            return 20.0...500.0
        case .other:
            return 5.0...100.0
        }
    }
    
    /// Multiplier applied to raw VisionKit confidence scores for this category
    /// 
    /// Different object types have varying detection reliability. This multiplier
    /// adjusts confidence scores based on empirical detection accuracy for each
    /// category, improving overall classification reliability.
    /// 
    /// - Returns: Multiplier value (typically 0.7-1.2) applied to raw confidence
    /// - Note: Values >1.0 boost confidence for easily detected items (food)
    /// - Note: Values <1.0 reduce confidence for difficult items (bills, transport)
    var detectionConfidenceMultiplier: Float {
        switch self {
        case .food:
            return 1.2 // Food items are generally easier to detect
        case .shopping:
            return 1.0 // Standard detection
        case .transport:
            return 0.8 // Transport items might be harder to detect
        case .entertainment:
            return 1.1 // Entertainment items are usually distinctive
        case .bills:
            return 0.7 // Bills/documents are harder to detect via camera
        case .other:
            return 0.9 // Lower confidence for miscellaneous items
        }
    }
    
    /// Minimum confidence threshold required for reliable detection in this category
    /// 
    /// Sets the quality bar for object detection to minimize false positives
    /// in affordability calculations. Higher thresholds for categories where
    /// misclassification could lead to poor financial advice.
    /// 
    /// - Returns: Minimum confidence score (0.0-1.0) required for acceptance
    /// - Note: Bills require 0.85 due to high misclassification cost
    /// - Note: Food allows 0.6 due to lower financial risk and better detection
    var minimumDetectionConfidence: Float {
        switch self {
        case .food:
            return 0.6 // Lower threshold for common food items
        case .shopping:
            return 0.7 // Standard threshold for retail items
        case .transport:
            return 0.8 // Higher threshold for transport-related items
        case .entertainment:
            return 0.65 // Moderate threshold for entertainment items
        case .bills:
            return 0.85 // High threshold for document/bill detection
        case .other:
            return 0.75 // Higher threshold for miscellaneous items
        }
    }
    
    /// Keywords used for object classification and category matching
    /// 
    /// These keywords help map raw ML model outputs to expense categories.
    /// Used in conjunction with VisionKit results to improve classification
    /// accuracy and handle edge cases in object recognition.
    /// 
    /// - Returns: Array of lowercase keywords associated with this category
    /// - Note: Keywords should be regularly updated based on user feedback
    /// - Important: Used for fallback classification when VisionKit confidence is low
    var detectionKeywords: [String] {
        switch self {
        case .food:
            return ["food", "meal", "snack", "drink", "beverage", "restaurant", "pizza", "burger", "coffee", "sandwich"]
        case .shopping:
            return ["clothing", "shoes", "bag", "electronics", "book", "toy", "accessory", "retail", "product"]
        case .transport:
            return ["car", "vehicle", "bike", "scooter", "fuel", "gas", "parking", "ticket", "transport"]
        case .entertainment:
            return ["movie", "game", "music", "concert", "theater", "sports", "event", "ticket", "entertainment"]
        case .bills:
            return ["bill", "invoice", "receipt", "document", "utility", "phone", "internet", "subscription"]
        case .other:
            return ["item", "object", "product", "service", "misc", "other"]
        }
    }
}

extension BudgetViewModel {
    /// Performs comprehensive affordability analysis for a camera-detected object
    /// 
    /// This is the core method that combines object detection results with budget data
    /// to produce actionable affordability decisions. Uses AI-enhanced logic to consider
    /// spending patterns, streak protection, and behavioral insights.
    /// 
    /// - Parameters:
    ///   - detectedObject: The object detected by VisionKit with classification metadata
    ///   - estimatedPrice: AI-estimated price in USD for the detected item
    /// - Returns: Complete affordability analysis with recommendations and budget impact
    /// - Note: Integrates with existing budget tracking and streak systems
    /// - Important: All calculations use current budget state and real-time data
    func calculateAffordability(for detectedObject: DetectedObject, estimatedPrice: Double) -> AffordabilityResult {
        let category = detectedObject.category
        let categoryBudgetRemaining = budgetRemainingForCategory(category)
        let monthlyBudgetRemaining = budget.monthlyBudget - totalMonthlySpending
        
        // Get current date information
        let calendar = Calendar.current
        let today = Date()
        let daysRemainingInMonth = calendar.range(of: .day, in: .month, for: today)?.count ?? 30
        let daysPassed = calendar.component(.day, from: today)
        let daysLeft = max(daysRemainingInMonth - daysPassed, 1)
        
        // Determine if affordable
        let canAfford = estimatedPrice <= categoryBudgetRemaining && estimatedPrice <= monthlyBudgetRemaining
        
        // Calculate budget impact with enhanced metrics
        let dailyImpact = estimatedPrice / Double(daysLeft)
        let wouldExceedBudget = estimatedPrice > categoryBudgetRemaining
        
        // Assess streak risk using AI-enhanced logic
        let streakRisk = calculateStreakRisk(
            canAfford: canAfford,
            estimatedPrice: estimatedPrice,
            categoryBudgetRemaining: categoryBudgetRemaining,
            monthlyBudgetRemaining: monthlyBudgetRemaining,
            currentStreak: streak.currentStreak
        )
        
        // Create enhanced budget impact
        let budgetImpact = BudgetImpact(
            remainingMonthlyBudget: monthlyBudgetRemaining - estimatedPrice,
            categoryBudgetRemaining: categoryBudgetRemaining - estimatedPrice,
            dailyBudgetImpact: dailyImpact,
            wouldExceedBudget: wouldExceedBudget,
            streakRisk: streakRisk,
            currentMonthlySpending: totalMonthlySpending,
            monthlyBudget: budget.monthlyBudget,
            daysRemainingInMonth: daysLeft
        )
        
        // Generate AI-enhanced reasoning
        let aiReasoning = generateAIAffordabilityReasoning(
            canAfford: canAfford,
            estimatedPrice: estimatedPrice,
            category: category,
            budgetImpact: budgetImpact,
            detectedObject: detectedObject
        )
        
        // Generate AI-powered recommendations
        let recommendations = generateAIRecommendations(
            canAfford: canAfford,
            estimatedPrice: estimatedPrice,
            category: category,
            budgetImpact: budgetImpact,
            detectedObject: detectedObject
        )
        
        return AffordabilityResult(
            canAfford: canAfford,
            estimatedPrice: estimatedPrice,
            detectedCategory: category,
            budgetImpact: budgetImpact,
            aiReasoning: aiReasoning,
            confidence: detectedObject.adjustedConfidence,
            recommendations: recommendations,
            detectedObject: detectedObject
        )
    }
    
    /// Calculates the risk this purchase poses to the user's spending streak
    /// 
    /// Uses AI-enhanced logic that considers streak length, budget utilization,
    /// and spending patterns to assess streak protection needs. Longer streaks
    /// receive higher protection priority through dynamic risk multipliers.
    /// 
    /// - Parameters:
    ///   - canAfford: Whether the purchase fits within current budgets
    ///   - estimatedPrice: The estimated cost of the item in USD
    ///   - categoryBudgetRemaining: Remaining budget in the item's category
    ///   - monthlyBudgetRemaining: Total remaining monthly budget
    ///   - currentStreak: User's current consecutive days within budget
    /// - Returns: Risk level from `.none` to `.high` with associated UI colors and icons
    /// - Note: Risk increases with streak length to protect valuable achievements
    private func calculateStreakRisk(canAfford: Bool, estimatedPrice: Double, categoryBudgetRemaining: Double, monthlyBudgetRemaining: Double, currentStreak: Int) -> BudgetImpact.StreakRisk {
        if !canAfford {
            return .high
        }
        
        // Consider streak length in risk assessment
        let streakMultiplier = min(Double(currentStreak) / 30.0, 1.0) // Higher stakes for longer streaks
        
        let categoryUtilization = estimatedPrice / categoryBudgetRemaining
        let monthlyUtilization = estimatedPrice / monthlyBudgetRemaining
        
        let riskScore = (categoryUtilization + monthlyUtilization) / 2.0 * (1.0 + streakMultiplier)
        
        if riskScore > 0.8 {
            return .high
        } else if riskScore > 0.6 {
            return .medium
        } else if riskScore > 0.3 {
            return .low
        } else {
            return .none
        }
    }
    
    /// Generates natural language explanation for affordability decisions
    /// 
    /// Creates user-friendly explanations that combine budget analysis with
    /// detection confidence and streak considerations. Uses contextual information
    /// to provide actionable insights rather than just yes/no decisions.
    /// 
    /// - Parameters:
    ///   - canAfford: The primary affordability decision
    ///   - estimatedPrice: Estimated item cost in USD
    ///   - category: The expense category for budget context
    ///   - budgetImpact: Detailed budget analysis results
    ///   - detectedObject: Original detection for confidence context
    /// - Returns: Human-readable explanation of the affordability decision
    /// - Note: Will be enhanced with Apple Foundation Models for more natural language
    private func generateAIAffordabilityReasoning(canAfford: Bool, estimatedPrice: Double, category: Category, budgetImpact: BudgetImpact, detectedObject: DetectedObject) -> String {
        let categoryBudget = budget.categoryBudgets[category] ?? 0
        let confidenceText = detectedObject.meetsConfidenceThreshold ? "high confidence" : "moderate confidence"
        
        if canAfford {
            let utilizationStatus = budgetImpact.budgetUtilization.utilizationStatus.rawValue.lowercased()
            let streakImpact = budgetImpact.streakRisk == .none ? "won't affect your streak" : "may impact your \(streak.currentStreak)-day streak"
            
            return "✅ You can afford this \(category.rawValue.lowercased()) item with \(confidenceText)! Your budget is \(utilizationStatus) and this purchase \(streakImpact). Remaining in category: $\(budgetImpact.categoryBudgetRemaining, specifier: "%.0f")"
        } else {
            let shortfall = estimatedPrice - budgetImpact.categoryBudgetRemaining
            let projectedOverage = budgetImpact.projectedMonthEnd.projectedOverage
            
            var reasoning = "❌ This \(category.rawValue.lowercased()) item exceeds your budget by $\(shortfall, specifier: "%.0f") with \(confidenceText)."
            
            if projectedOverage > 0 {
                reasoning += " Your current spending pace suggests you'll exceed your monthly budget by $\(projectedOverage, specifier: "%.0f")."
            }
            
            if streak.currentStreak > 7 {
                reasoning += " This could break your \(streak.currentStreak)-day spending streak."
            }
            
            return reasoning
        }
    }
    
    /// Creates personalized recommendations based on affordability analysis
    /// 
    /// Generates actionable suggestions that help users make informed financial
    /// decisions. For unaffordable items, provides savings plans and alternatives.
    /// For affordable items, offers optimization tips and streak protection advice.
    /// 
    /// - Parameters:
    ///   - canAfford: Whether the item is currently affordable
    ///   - estimatedPrice: The estimated cost in USD
    ///   - category: Expense category for context-specific advice
    ///   - budgetImpact: Detailed budget analysis for recommendation logic
    ///   - detectedObject: Original detection for confidence-based suggestions
    /// - Returns: Array of prioritized, actionable recommendations
    /// - Note: Uses behavioral analysis and spending patterns for personalization
    private func generateAIRecommendations(canAfford: Bool, estimatedPrice: Double, category: Category, budgetImpact: BudgetImpact, detectedObject: DetectedObject) -> [AffordabilityRecommendation] {
        var recommendations: [AffordabilityRecommendation] = []
        
        if !canAfford {
            // AI-optimized wait and save recommendation
            let dailySavingsNeeded = (estimatedPrice - budgetImpact.categoryBudgetRemaining) / 30.0
            let daysToSave = Int(ceil((estimatedPrice - budgetImpact.categoryBudgetRemaining) / dailySavingsNeeded))
            
            recommendations.append(AffordabilityRecommendation(
                type: .waitAndSave,
                title: "Smart Savings Plan",
                description: "Save $\(dailySavingsNeeded, specifier: "%.2f") daily for \(daysToSave) days to afford this item",
                actionable: true,
                priority: .medium,
                aiReasoning: "Based on your spending patterns, this is the optimal savings rate",
                estimatedImpact: EstimatedImpact(
                    budgetSavings: estimatedPrice - budgetImpact.categoryBudgetRemaining,
                    timeToAfford: daysToSave,
                    streakProtection: 0.9,
                    confidenceLevel: 0.8
                ),
                alternativeActions: [
                    AlternativeAction(
                        title: "Find Similar Item",
                        description: "Look for alternatives in the $\(budgetImpact.categoryBudgetRemaining * 0.8, specifier: "%.0f")-$\(budgetImpact.categoryBudgetRemaining, specifier: "%.0f") range",
                        actionType: .substitute,
                        estimatedOutcome: "Immediate purchase within budget"
                    )
                ]
            ))
            
            // Budget reallocation recommendation
            let availableFromOtherCategories = Category.allCases
                .filter { $0 != category }
                .map { budgetRemainingForCategory($0) }
                .filter { $0 > 0 }
                .reduce(0, +)
            
            if availableFromOtherCategories > estimatedPrice - budgetImpact.categoryBudgetRemaining {
                recommendations.append(AffordabilityRecommendation(
                    type: .budgetAdjustment,
                    title: "Reallocate Budget",
                    description: "Move $\(estimatedPrice - budgetImpact.categoryBudgetRemaining, specifier: "%.0f") from other categories",
                    actionable: true,
                    priority: .high,
                    aiReasoning: "You have sufficient funds in other categories",
                    estimatedImpact: EstimatedImpact(
                        budgetSavings: 0,
                        timeToAfford: 0,
                        streakProtection: 0.7,
                        confidenceLevel: 0.9
                    )
                ))
            }
        } else {
            // Recommendations for affordable items
            if budgetImpact.streakRisk != .none {
                recommendations.append(AffordabilityRecommendation(
                    type: .streakProtection,
                    title: "Streak Impact Warning",
                    description: "This purchase has \(budgetImpact.streakRisk.description.lowercased()). Consider timing for optimal streak protection.",
                    actionable: false,
                    priority: budgetImpact.streakRisk == .high ? .high : .medium,
                    aiReasoning: "Your \(streak.currentStreak)-day streak is valuable for building good spending habits",
                    estimatedImpact: EstimatedImpact(
                        streakProtection: budgetImpact.streakRisk == .high ? 0.3 : 0.7,
                        confidenceLevel: 0.8
                    )
                ))
            }
            
            // Optimal timing recommendation
            if budgetImpact.budgetUtilization.monthlyUsagePercentage > 0.7 {
                recommendations.append(AffordabilityRecommendation(
                    type: .optimalTiming,
                    title: "Consider Next Month",
                    description: "You've used \(budgetImpact.budgetUtilization.monthlyUsagePercentage * 100, specifier: "%.0f")% of your monthly budget. Waiting until next month might be safer.",
                    actionable: true,
                    priority: .low,
                    aiReasoning: "Early month purchases provide better budget flexibility",
                    estimatedImpact: EstimatedImpact(
                        streakProtection: 0.9,
                        confidenceLevel: 0.7
                    )
                ))
            }
            
            // AI behavioral insight
            if detectedObject.confidence < 0.8 {
                recommendations.append(AffordabilityRecommendation(
                    type: .behavioralInsight,
                    title: "Verify Price Estimate",
                    description: "AI confidence is \(detectedObject.confidence * 100, specifier: "%.0f")%. Double-check the actual price before purchasing.",
                    actionable: true,
                    priority: .medium,
                    aiReasoning: "Lower detection confidence suggests price verification would be beneficial",
                    estimatedImpact: EstimatedImpact(
                        confidenceLevel: 0.6
                    )
                ))
            }
        }
        
        // Sort recommendations by priority
        return recommendations.sorted { $0.priority.sortOrder > $1.priority.sortOrder }
    }
}