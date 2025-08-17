//
//  AffordabilityModels.swift
//  Penny
//
//  Created by Kiro on 8/17/25.
//

import Foundation
import Vision

// MARK: - Detected Object Model

struct DetectedObject: Identifiable, Codable {
    let id = UUID()
    let category: Category
    let confidence: Float
    let boundingBox: CGRect
    let timestamp: Date
    let rawClassification: String // Original ML model classification
    let alternativeCategories: [CategoryConfidence] // Alternative category suggestions
    let detectionSource: DetectionSource
    
    init(category: Category, confidence: Float, boundingBox: CGRect, rawClassification: String = "", alternativeCategories: [CategoryConfidence] = [], detectionSource: DetectionSource = .vision) {
        self.category = category
        self.confidence = confidence
        self.boundingBox = boundingBox
        self.rawClassification = rawClassification
        self.alternativeCategories = alternativeCategories
        self.detectionSource = detectionSource
        self.timestamp = Date()
    }
    
    /// Adjusted confidence based on category-specific multipliers
    var adjustedConfidence: Float {
        return min(confidence * category.detectionConfidenceMultiplier, 1.0)
    }
    
    /// Whether this detection meets the minimum confidence threshold
    var meetsConfidenceThreshold: Bool {
        return adjustedConfidence >= category.minimumDetectionConfidence
    }
    
    /// Best alternative category if primary doesn't meet threshold
    var bestAlternative: CategoryConfidence? {
        return alternativeCategories.first { $0.confidence >= $0.category.minimumDetectionConfidence }
    }
}

// MARK: - Supporting Detection Models

struct CategoryConfidence: Codable {
    let category: Category
    let confidence: Float
    let reasoning: String
    
    init(category: Category, confidence: Float, reasoning: String = "") {
        self.category = category
        self.confidence = confidence
        self.reasoning = reasoning
    }
}

enum DetectionSource: String, Codable, CaseIterable {
    case vision = "VisionKit"
    case coreML = "Core ML"
    case foundationModels = "Apple Foundation Models"
    case manual = "Manual Selection"
    
    var displayName: String {
        return rawValue
    }
}

// MARK: - Affordability Result Model

struct AffordabilityResult: Identifiable, Codable {
    let id = UUID()
    let canAfford: Bool
    let estimatedPrice: Double
    let priceRange: ClosedRange<Double>
    let detectedCategory: Category
    let budgetImpact: BudgetImpact
    let aiReasoning: String
    let confidence: Float
    let recommendations: [AffordabilityRecommendation]
    let timestamp: Date
    let detectedObject: DetectedObject
    let transactionPreview: TransactionPreview // Preview for easy Transaction creation
    
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
        
        // Create transaction preview for seamless integration
        self.transactionPreview = TransactionPreview(
            amount: estimatedPrice,
            category: detectedCategory,
            note: "Camera detected: \(detectedObject.rawClassification)",
            confidence: confidence
        )
    }
    
    /// Color for UI feedback based on affordability
    var feedbackColor: String {
        return canAfford ? "green" : "red"
    }
    
    /// Icon for UI feedback
    var feedbackIcon: String {
        return canAfford ? "checkmark.circle.fill" : "xmark.circle.fill"
    }
    
    /// Quick summary for display
    var quickSummary: String {
        let affordabilityText = canAfford ? "✅ Affordable" : "❌ Not Affordable"
        return "\(affordabilityText) • $\(estimatedPrice, specifier: "%.0f") • \(detectedCategory.rawValue)"
    }
}

// MARK: - Transaction Preview Model

struct TransactionPreview: Codable {
    let amount: Double
    let category: Category
    let note: String
    let confidence: Float
    let suggestedAdjustments: [String]
    
    init(amount: Double, category: Category, note: String, confidence: Float) {
        self.amount = amount
        self.category = category
        self.note = note
        self.confidence = confidence
        
        // Generate suggested adjustments based on confidence
        var adjustments: [String] = []
        if confidence < 0.8 {
            adjustments.append("Consider adjusting the amount")
        }
        if confidence < 0.7 {
            adjustments.append("Verify the category")
        }
        self.suggestedAdjustments = adjustments
    }
    
    /// Create Transaction data for the existing system
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

struct BudgetImpact: Codable {
    let remainingMonthlyBudget: Double
    let categoryBudgetRemaining: Double
    let dailyBudgetImpact: Double
    let wouldExceedBudget: Bool
    let streakRisk: StreakRisk
    let budgetUtilization: BudgetUtilization
    let projectedMonthEnd: ProjectedMonthEnd
    let smartRecommendations: [SmartBudgetRecommendation]
    
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
    /// Estimated price ranges for different categories (in USD)
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
    
    /// Confidence multiplier for object detection in this category
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
    
    /// Camera detection confidence threshold for this category
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
    
    /// Camera detection keywords for object classification
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
    /// Calculate affordability for a detected object using AI-enhanced budget analysis
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
    
    /// AI-enhanced streak risk calculation
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
    
    /// Generate AI-enhanced affordability reasoning
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
    
    /// Generate AI-powered recommendations with behavioral insights
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