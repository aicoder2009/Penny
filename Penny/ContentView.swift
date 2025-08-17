//
//  ContentView.swift
//  Penny
//
//  Created by Karthick Kilash Arun on 7/14/25.
//

import SwiftUI

// MARK: - Data Models

struct Transaction: Identifiable, Codable {
    let id = UUID()
    let amount: Double
    let category: Category?
    let incomeCategory: IncomeCategory?
    let isIncome: Bool
    let date: Date
    let note: String
    
    var displayCategory: String {
        if isIncome {
            return incomeCategory?.rawValue ?? "Other Income"
        } else {
            return category?.rawValue ?? "Other"
        }
    }
    
    var displayIcon: String {
        if isIncome {
            return incomeCategory?.icon ?? "💰"
        } else {
            return category?.icon ?? "📝"
        }
    }
}

enum Category: String, CaseIterable, Codable {
    case food = "Food"
    case shopping = "Shopping"
    case transport = "Transport"
    case entertainment = "Entertainment"
    case bills = "Bills"
    case other = "Other"
    
    var icon: String {
        switch self {
        case .food: return "🍕"
        case .shopping: return "🛒"
        case .transport: return "🚗"
        case .entertainment: return "🎬"
        case .bills: return "💡"
        case .other: return "📝"
        }
    }
}

enum IncomeCategory: String, CaseIterable, Codable {
    case salary = "Salary/Wages"
    case freelance = "Freelance/Contract"
    case business = "Business Income"
    case investment = "Investment/Interest"
    case gift = "Gift/Transfer"
    case other = "Other Income"
    
    var icon: String {
        switch self {
        case .salary: return "💼"
        case .freelance: return "🖥️"
        case .business: return "🏢"
        case .investment: return "📈"
        case .gift: return "🎁"
        case .other: return "💰"
        }
    }
}

struct Budget: Codable {
    var monthlyBudget: Double = 1000.0
    var categoryBudgets: [Category: Double] = [
        .food: 300.0,
        .shopping: 200.0,
        .transport: 150.0,
        .entertainment: 100.0,
        .bills: 250.0,
        .other: 100.0
    ]
    var currentMonth: Int = Calendar.current.component(.month, from: Date())
    var currentYear: Int = Calendar.current.component(.year, from: Date())
}

struct SpendingStreak: Codable {
    var currentStreak: Int = 0
    var longestStreak: Int = 0
    var lastCheckDate: Date = Date()
    var dailyBudgetHistory: [String: Bool] = [:] // Date string: wasWithinBudget
}

// MARK: - Enhanced View Model

class BudgetViewModel: ObservableObject {
    @Published var transactions: [Transaction] = []
    @Published var budget = Budget()
    @Published var streak = SpendingStreak()
    @Published var isPrivateMode = false
    
    @AppStorage("savedTransactions") private var savedTransactionsData: Data = Data()
    @AppStorage("savedBudget") private var savedBudgetData: Data = Data()
    @AppStorage("savedStreak") private var savedStreakData: Data = Data()
    
    var balance: Double {
        transactions.reduce(0) { total, transaction in
            total + (transaction.isIncome ? transaction.amount : -transaction.amount)
        }
    }
    
    var expenseTotal: Double {
        transactions.filter { !$0.isIncome }.reduce(0) { $0 + $1.amount }
    }
    
    var incomeTotal: Double {
        transactions.filter { $0.isIncome }.reduce(0) { $0 + $1.amount }
    }
    
    // Current month's transactions
    var currentMonthTransactions: [Transaction] {
        let currentMonth = Calendar.current.component(.month, from: Date())
        let currentYear = Calendar.current.component(.year, from: Date())
        
        return transactions.filter { transaction in
            let month = Calendar.current.component(.month, from: transaction.date)
            let year = Calendar.current.component(.year, from: transaction.date)
            return month == currentMonth && year == currentYear
        }
    }
    
    // Category spending for current month
    func spentInCategory(_ category: Category) -> Double {
        currentMonthTransactions
            .filter { !$0.isIncome && $0.category == category }
            .reduce(0) { $0 + $1.amount }
    }
    
    // Budget remaining for category
    func budgetRemainingForCategory(_ category: Category) -> Double {
        let budgetAmount = budget.categoryBudgets[category] ?? 0
        let spent = spentInCategory(category)
        return budgetAmount - spent
    }
    
    // Total monthly spending
    var totalMonthlySpending: Double {
        currentMonthTransactions
            .filter { !$0.isIncome }
            .reduce(0) { $0 + $1.amount }
    }
    
    // Budget status for category (0.0 to 1.0+)
    func budgetProgressForCategory(_ category: Category) -> Double {
        let budgetAmount = budget.categoryBudgets[category] ?? 0
        guard budgetAmount > 0 else { return 0 }
        return spentInCategory(category) / budgetAmount
    }
    
    // Check if within daily budget
    var isWithinDailyBudget: Bool {
        let calendar = Calendar.current
        let today = Date()
        guard let startOfMonth = calendar.dateInterval(of: .month, for: today)?.start,
              let daysInMonth = calendar.range(of: .day, in: .month, for: today)?.count else {
            return false
        }
        
        let daysPassed = calendar.dateComponents([.day], from: startOfMonth, to: today).day ?? 0
        let daysRemaining = max(daysInMonth - daysPassed, 1) // Ensure at least 1 day remaining
        
        let budgetRemaining = budget.monthlyBudget - totalMonthlySpending
        let dailyBudgetAllowance = budgetRemaining / Double(daysRemaining)
        
        let todaySpending = currentMonthTransactions
            .filter { !$0.isIncome && calendar.isDate($0.date, inSameDayAs: today) }
            .reduce(0) { $0 + $1.amount }
        
        return todaySpending <= dailyBudgetAllowance
    }
    
    init() {
        loadData()
    }
    
    private let saveQueue = DispatchQueue(label: "com.penny.save", qos: .utility)
    
    func addTransaction(_ transaction: Transaction) {
        transactions.append(transaction)
        saveDataSafely()
        updateStreak()
    }
    
    func deleteTransaction(_ transaction: Transaction) {
        transactions.removeAll { $0.id == transaction.id }
        saveDataSafely()
        updateStreak()
    }
    
    func saveDataSafely() {
        saveQueue.async { [weak self] in
            guard let self = self else { return }
            
            do {
                // Save transactions
                let transactionData = try JSONEncoder().encode(self.transactions)
                let budgetData = try JSONEncoder().encode(self.budget)
                let streakData = try JSONEncoder().encode(self.streak)
                
                DispatchQueue.main.async {
                    self.savedTransactionsData = transactionData
                    self.savedBudgetData = budgetData
                    self.savedStreakData = streakData
                }
            } catch {
                print("Failed to save data: \(error)")
            }
        }
    }
    
    func loadData() {
        do {
            // Load transactions
            if !savedTransactionsData.isEmpty {
                transactions = try JSONDecoder().decode([Transaction].self, from: savedTransactionsData)
            }
            
            // Load budget
            if !savedBudgetData.isEmpty {
                budget = try JSONDecoder().decode(Budget.self, from: savedBudgetData)
            }
            
            // Load streak
            if !savedStreakData.isEmpty {
                streak = try JSONDecoder().decode(SpendingStreak.self, from: savedStreakData)
            }
        } catch {
            print("Failed to load data: \(error)")
            // Reset to defaults on corruption
            transactions = []
            budget = Budget()
            streak = SpendingStreak()
        }
        
        updateStreak()
    }
    
    // Update streak
    func updateStreak() {
        let calendar = Calendar.current
        let today = Date()
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today) ?? today
        
        // Check if we already checked today
        if calendar.isDate(streak.lastCheckDate, inSameDayAs: today) {
            return
        }
        
        // Clean up old history entries (keep only last 90 days)
        cleanupStreakHistory()
        
        // If yesterday was within budget, continue or start streak
        let yesterdayKey = DateFormatter.dayKey.string(from: yesterday)
        let wasYesterdayWithinBudget = streak.dailyBudgetHistory[yesterdayKey] ?? false
        
        if wasYesterdayWithinBudget {
            streak.currentStreak += 1
            if streak.currentStreak > streak.longestStreak {
                streak.longestStreak = streak.currentStreak
            }
        } else {
            streak.currentStreak = 0
        }
        
        // Record today's budget status
        let todayKey = DateFormatter.dayKey.string(from: today)
        streak.dailyBudgetHistory[todayKey] = isWithinDailyBudget
        streak.lastCheckDate = today
        
        saveDataSafely()
    }
    
    private func cleanupStreakHistory() {
        let calendar = Calendar.current
        let cutoffDate = calendar.date(byAdding: .day, value: -90, to: Date()) ?? Date()
        let cutoffKey = DateFormatter.dayKey.string(from: cutoffDate)
        
        streak.dailyBudgetHistory = streak.dailyBudgetHistory.filter { key, _ in
            key >= cutoffKey
        }
    }
}

extension DateFormatter {
    static let dayKey: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}

// MARK: - Main Content View with Tabs

struct ContentView: View {
    @StateObject private var viewModel = BudgetViewModel()
    @State private var showingCameraScanner = false
    
    var body: some View {
        TabView {
            DashboardView(viewModel: viewModel)
                .tabItem {
                    Image(systemName: "house.fill")
                    Text("Dashboard")
                }
            
            // Camera Affordability Scanner Tab
            CameraScannerTabView(viewModel: viewModel, showingCameraScanner: $showingCameraScanner)
                .tabItem {
                    Image(systemName: "camera.viewfinder")
                    Text("Scan")
                }
            
            BudgetOverviewView(viewModel: viewModel)
                .tabItem {
                    Image(systemName: "chart.pie.fill")
                    Text("Budget")
                }
            
            TransactionsListView(viewModel: viewModel)
                .tabItem {
                    Image(systemName: "list.bullet")
                    Text("Transactions")
                }
        }
        .onAppear {
            viewModel.loadData()
        }
        .fullScreenCover(isPresented: $showingCameraScanner) {
            CameraAffordabilityView(budgetViewModel: viewModel)
        }
    }
}

// MARK: - Camera Scanner Tab View

struct CameraScannerTabView: View {
    @ObservedObject var viewModel: BudgetViewModel
    @Binding var showingCameraScanner: Bool
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                Spacer()
                
                // Camera Icon and Title
                VStack(spacing: 16) {
                    Image(systemName: "camera.viewfinder")
                        .font(.system(size: 80))
                        .foregroundColor(.blue)
                    
                    Text("Camera Affordability Scanner")
                        .font(.title2)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                    
                    Text("Point your camera at any item to get instant affordability decisions based on your AI-optimized budget")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                
                // Scan Button
                Button(action: {
                    showingCameraScanner = true
                }) {
                    HStack {
                        Image(systemName: "camera.fill")
                        Text("Start Scanning")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(12)
                }
                .padding(.horizontal)
                
                // Test Button (for development)
                Button(action: {
                    runCameraAffordabilityTests()
                }) {
                    HStack {
                        Image(systemName: "testtube.2")
                        Text("Test Scanner Logic")
                    }
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }
                .padding(.horizontal)
                
                // Quick Budget Status
                VStack(alignment: .leading, spacing: 12) {
                    Text("Current Budget Status")
                        .font(.headline)
                    
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Monthly Budget")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("$\(viewModel.budget.monthlyBudget, specifier: "%.0f")")
                                .font(.title3)
                                .fontWeight(.semibold)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing) {
                            Text("Remaining")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("$\(viewModel.budget.monthlyBudget - viewModel.totalMonthlySpending, specifier: "%.0f")")
                                .font(.title3)
                                .fontWeight(.semibold)
                                .foregroundColor(viewModel.budget.monthlyBudget - viewModel.totalMonthlySpending >= 0 ? .green : .red)
                        }
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .padding(.horizontal)
                
                Spacer()
            }
            .navigationTitle("Scan Items")
        }
    }
}

// MARK: - Enhanced Dashboard View

struct DashboardView: View {
    @ObservedObject var viewModel: BudgetViewModel
    @State private var showingAddTransaction = false
    @State private var isAddingIncome = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Balance Card
                    VStack(spacing: 8) {
                        Text("Current Balance")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        Text("$\(viewModel.balance, specifier: "%.2f")")
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                            .foregroundColor(viewModel.balance >= 0 ? .green : .red)
                    }
                    .padding(.vertical, 30)
                    .frame(maxWidth: .infinity)
                    .background(Color(.systemGray6))
                    .cornerRadius(16)
                    .padding(.horizontal)
                    
                    // Quick Stats
                    HStack(spacing: 20) {
                        VStack {
                            Text("Income")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("$\(viewModel.incomeTotal, specifier: "%.2f")")
                                .font(.title3)
                                .fontWeight(.semibold)
                                .foregroundColor(.green)
                        }
                        
                        VStack {
                            Text("Expenses")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("$\(viewModel.expenseTotal, specifier: "%.2f")")
                                .font(.title3)
                                .fontWeight(.semibold)
                                .foregroundColor(.red)
                        }
                    }
                    .padding(.horizontal)
                    
                    // Spending Streak
                    SpendingStreakView(viewModel: viewModel)
                        .padding(.horizontal)
                    
                    // Action Buttons
                    HStack(spacing: 16) {
                        Button(action: {
                            isAddingIncome = true
                            showingAddTransaction = true
                        }) {
                            Label("Add Income", systemImage: "plus.circle.fill")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.green)
                                .cornerRadius(12)
                        }
                        
                        Button(action: {
                            isAddingIncome = false
                            showingAddTransaction = true
                        }) {
                            Label("Add Expense", systemImage: "minus.circle.fill")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.red)
                                .cornerRadius(12)
                        }
                    }
                    .padding(.horizontal)
                    
                    // Quick Budget Overview
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Quick Budget Status")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(Array(Category.allCases.prefix(3)), id: \.self) { category in
                                    CategoryBudgetCard(category: category, viewModel: viewModel)
                                        .frame(width: 160)
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                    
                    // Recent Transactions
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Recent Transactions")
                                .font(.headline)
                            Spacer()
                        }
                        .padding(.horizontal)
                        
                        if viewModel.transactions.isEmpty {
                            Text("No transactions yet")
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding()
                        } else {
                            LazyVStack(spacing: 8) {
                                ForEach(viewModel.transactions.reversed().prefix(5)) { transaction in
                                    TransactionRow(transaction: transaction, viewModel: viewModel)
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                    
                    Spacer()
                }
            }
            .navigationTitle("Penny")
            .sheet(isPresented: $showingAddTransaction) {
                AddTransactionView(isIncome: isAddingIncome, viewModel: viewModel)
            }
        }
    }
}

// MARK: - Budget Overview View

struct BudgetOverviewView: View {
    @ObservedObject var viewModel: BudgetViewModel
    @State private var showingBudgetSettings = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Monthly Budget Progress
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Monthly Budget")
                                .font(.headline)
                            Spacer()
                            Button("Edit") {
                                showingBudgetSettings = true
                            }
                            .foregroundColor(.blue)
                        }
                        
                        let progress = viewModel.totalMonthlySpending / viewModel.budget.monthlyBudget
                        let remaining = viewModel.budget.monthlyBudget - viewModel.totalMonthlySpending
                        
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("$\(viewModel.totalMonthlySpending, specifier: "%.2f")")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                Text("of $\(viewModel.budget.monthlyBudget, specifier: "%.2f")")
                                    .font(.title3)
                                    .foregroundColor(.secondary)
                            }
                            
                            ProgressView(value: min(progress, 1.0))
                                .progressViewStyle(LinearProgressViewStyle(tint: progress > 1.0 ? .red : progress > 0.8 ? .orange : .green))
                            
                            Text("$\(remaining, specifier: "%.2f") remaining")
                                .font(.caption)
                                .foregroundColor(remaining >= 0 ? .green : .red)
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    
                    // Category Budgets
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Category Budgets")
                            .font(.headline)
                        
                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: 16) {
                            ForEach(Category.allCases, id: \.self) { category in
                                CategoryBudgetCard(category: category, viewModel: viewModel)
                            }
                        }
                    }
                    
                    // Spending Insights
                    SpendingInsightsView(viewModel: viewModel)
                }
                .padding()
            }
            .navigationTitle("Budget")
            .sheet(isPresented: $showingBudgetSettings) {
                BudgetSettingsView(viewModel: viewModel)
            }
        }
    }
}

// MARK: - Spending Streak View

struct SpendingStreakView: View {
    @ObservedObject var viewModel: BudgetViewModel
    
    var body: some View {
        VStack(spacing: 16) {
            // Streak Counter
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .stroke(Color.orange.opacity(0.3), lineWidth: 8)
                        .frame(width: 120, height: 120)
                    
                    Circle()
                        .trim(from: 0, to: min(Double(viewModel.streak.currentStreak) / 30.0, 1.0))
                        .stroke(Color.orange, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .frame(width: 120, height: 120)
                        .rotationEffect(.degrees(-90))
                    
                    VStack {
                        Text("🔥")
                            .font(.system(size: 30))
                        Text("\(viewModel.streak.currentStreak)")
                            .font(.title)
                            .fontWeight(.bold)
                    }
                }
                
                Text("days on budget")
                    .font(.headline)
                    .foregroundColor(.secondary)
            }
            
            // Streak Stats
            HStack(spacing: 40) {
                VStack {
                    Text("\(viewModel.streak.longestStreak)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.orange)
                    Text("Best Streak")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                VStack {
                    Text(viewModel.isWithinDailyBudget ? "✅" : "❌")
                        .font(.title2)
                    Text("Today")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
        .onAppear {
            viewModel.updateStreak()
        }
    }
}

// MARK: - Category Budget Card

struct CategoryBudgetCard: View {
    let category: Category
    @ObservedObject var viewModel: BudgetViewModel
    
    var body: some View {
        let spent = viewModel.spentInCategory(category)
        let budget = viewModel.budget.categoryBudgets[category] ?? 0
        let progress = budget > 0 ? spent / budget : 0
        let remaining = budget - spent
        
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(category.icon)
                    .font(.title2)
                Text(category.rawValue)
                    .font(.caption)
                    .fontWeight(.medium)
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("$\(spent, specifier: "%.0f")")
                        .font(.headline)
                        .fontWeight(.bold)
                    Text("/ $\(budget, specifier: "%.0f")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                ProgressView(value: min(progress, 1.0))
                    .progressViewStyle(LinearProgressViewStyle(tint: progress > 1.0 ? .red : progress > 0.8 ? .orange : .green))
                
                Text("$\(remaining, specifier: "%.0f") left")
                    .font(.caption)
                    .foregroundColor(remaining >= 0 ? .green : .red)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2)
    }
}

// MARK: - Budget Settings View

struct BudgetSettingsView: View {
    @ObservedObject var viewModel: BudgetViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var monthlyBudget: String
    @State private var categoryBudgets: [Category: String] = [:]
    
    init(viewModel: BudgetViewModel) {
        self.viewModel = viewModel
        self._monthlyBudget = State(initialValue: String(format: "%.0f", viewModel.budget.monthlyBudget))
        
        let budgets = Category.allCases.reduce(into: [Category: String]()) { result, category in
            result[category] = String(format: "%.0f", viewModel.budget.categoryBudgets[category] ?? 0)
        }
        self._categoryBudgets = State(initialValue: budgets)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("Monthly Budget") {
                    HStack {
                        Text("$")
                        TextField("Monthly Budget", text: $monthlyBudget)
                            .keyboardType(.numberPad)
                    }
                }
                
                Section("Category Budgets") {
                    ForEach(Category.allCases, id: \.self) { category in
                        HStack {
                            Text(category.icon)
                            Text(category.rawValue)
                            Spacer()
                            HStack {
                                Text("$")
                                TextField("0", text: Binding(
                                    get: { categoryBudgets[category] ?? "0" },
                                    set: { categoryBudgets[category] = $0 }
                                ))
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 80)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Budget Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveBudget()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
    
    private func saveBudget() {
        if let monthly = Double(monthlyBudget) {
            viewModel.budget.monthlyBudget = monthly
        }
        
        for category in Category.allCases {
            if let amount = Double(categoryBudgets[category] ?? "0") {
                viewModel.budget.categoryBudgets[category] = amount
            }
        }
        
        viewModel.saveDataSafely()
        dismiss()
    }
}

// MARK: - Transactions List View

struct TransactionsListView: View {
    @ObservedObject var viewModel: BudgetViewModel
    @State private var showingAddTransaction = false
    @State private var isAddingIncome = false
    @State private var showingEditTransaction = false
    @State private var transactionToEdit: Transaction?
    
    var body: some View {
        NavigationView {
            VStack {
                if viewModel.transactions.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "list.bullet.rectangle")
                            .font(.system(size: 60))
                            .foregroundColor(.secondary)
                        Text("No transactions yet")
                            .font(.title2)
                            .foregroundColor(.secondary)
                        Text("Add your first transaction to get started")
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(viewModel.transactions.reversed()) { transaction in
                            TransactionRow(transaction: transaction, viewModel: viewModel)
                                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                                .listRowSeparator(.hidden)
                                .listRowBackground(Color.clear)
                                .swipeActions(edge: .trailing) {
                                    Button("Delete") {
                                        viewModel.deleteTransaction(transaction)
                                    }
                                    .tint(.red)
                                    
                                    Button("Edit") {
                                        transactionToEdit = transaction
                                        showingEditTransaction = true
                                    }
                                    .tint(.blue)
                                }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Transactions")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu("Add") {
                        Button("Add Income") {
                            isAddingIncome = true
                            showingAddTransaction = true
                        }
                        Button("Add Expense") {
                            isAddingIncome = false
                            showingAddTransaction = true
                        }
                    }
                }
            }
            .sheet(isPresented: $showingAddTransaction) {
                AddTransactionView(isIncome: isAddingIncome, viewModel: viewModel)
            }
        }
    }
}

// MARK: - Spending Insights View

struct SpendingInsightsView: View {
    @ObservedObject var viewModel: BudgetViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Spending Insights")
                .font(.headline)
            
            VStack(spacing: 12) {
                // Top spending category
                if let topCategory = Category.allCases.max(by: { viewModel.spentInCategory($0) < viewModel.spentInCategory($1) }),
                   viewModel.spentInCategory(topCategory) > 0 {
                    InsightCard(
                        icon: "chart.bar.fill",
                        title: "Top Category",
                        description: "\(topCategory.icon) \(topCategory.rawValue) - $\(String(format: "%.0f", viewModel.spentInCategory(topCategory)))",
                        color: .blue
                    )
                }
                
                // Budget status
                let budgetProgress = viewModel.totalMonthlySpending / viewModel.budget.monthlyBudget
                InsightCard(
                    icon: budgetProgress > 1.0 ? "exclamationmark.triangle.fill" : "checkmark.circle.fill",
                    title: budgetProgress > 1.0 ? "Over Budget" : "On Track",
                    description: budgetProgress > 1.0 ? "You're \(Int((budgetProgress - 1.0) * 100))% over your monthly budget" : "You're doing great staying within budget!",
                    color: budgetProgress > 1.0 ? .red : .green
                )
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct InsightCard: View {
    let icon: String
    let title: String
    let description: String
    let color: Color
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(color)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(8)
    }
}

// MARK: - Transaction Row Component

struct TransactionRow: View {
    let transaction: Transaction
    let viewModel: BudgetViewModel
    @State private var showingEditSheet = false
    @State private var showingDeleteAlert = false
    
    var body: some View {
        HStack {
            // Category Icon
            Text(transaction.displayIcon)
                .font(.title2)
                .frame(width: 40, height: 40)
                .background(Color(.systemGray5))
                .cornerRadius(8)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(transaction.displayCategory)
                    .font(.headline)
                
                if !transaction.note.isEmpty {
                    Text(transaction.note)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                Text(transaction.date, style: .date)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text("\(transaction.isIncome ? "+" : "-")$\(transaction.amount, specifier: "%.2f")")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(transaction.isIncome ? .green : .red)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}

// MARK: - Edit Transaction View

struct EditTransactionView: View {
    let transaction: Transaction
    let viewModel: BudgetViewModel
    
    @Environment(\.dismiss) private var dismiss
    @State private var amount: String
    @State private var selectedCategory: Category
    @State private var selectedIncomeCategory: IncomeCategory
    @State private var note: String
    
    init(transaction: Transaction, viewModel: BudgetViewModel) {
        self.transaction = transaction
        self.viewModel = viewModel
        self._amount = State(initialValue: String(format: "%.2f", transaction.amount))
        self._selectedCategory = State(initialValue: transaction.category ?? .food)
        self._selectedIncomeCategory = State(initialValue: transaction.incomeCategory ?? .salary)
        self._note = State(initialValue: transaction.note)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("Amount") {
                    HStack {
                        Text("$")
                            .font(.title)
                            .foregroundColor(.secondary)
                        
                        TextField("0.00", text: $amount)
                            .keyboardType(.decimalPad)
                            .font(.title)
                            .fontWeight(.semibold)
                    }
                }
                
                Section("Category") {
                    if transaction.isIncome {
                        Picker("Income Category", selection: $selectedIncomeCategory) {
                            ForEach(IncomeCategory.allCases, id: \.self) { category in
                                HStack {
                                    Text(category.icon)
                                    Text(category.rawValue)
                                }
                                .tag(category)
                            }
                        }
                        .pickerStyle(.wheel)
                    } else {
                        Picker("Expense Category", selection: $selectedCategory) {
                            ForEach(Category.allCases, id: \.self) { category in
                                HStack {
                                    Text(category.icon)
                                    Text(category.rawValue)
                                }
                                .tag(category)
                            }
                        }
                        .pickerStyle(.wheel)
                    }
                }
                
                Section("Note (Optional)") {
                    TextField("Add a note...", text: $note)
                }
            }
            .navigationTitle("Edit \(transaction.isIncome ? "Income" : "Expense")")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveChanges()
                    }
                    .fontWeight(.semibold)
                    .disabled(amount.isEmpty || Double(amount) == nil)
                }
            }
        }
    }
    
    private func saveChanges() {
        guard let amountValue = Double(amount), amountValue > 0 else { return }
        
        // Remove the old transaction
        viewModel.deleteTransaction(transaction)
        
        // Add the updated transaction
        let updatedTransaction = Transaction(
            amount: amountValue,
            category: transaction.isIncome ? nil : selectedCategory,
            incomeCategory: transaction.isIncome ? selectedIncomeCategory : nil,
            isIncome: transaction.isIncome,
            date: transaction.date, // Keep original date
            note: note
        )
        
        viewModel.addTransaction(updatedTransaction)
        dismiss()
    }
}

// MARK: - Add Transaction View

struct AddTransactionView: View {
    let isIncome: Bool
    let viewModel: BudgetViewModel
    
    @Environment(\.dismiss) private var dismiss
    @State private var amount = ""
    @State private var selectedCategory = Category.food
    @State private var selectedIncomeCategory = IncomeCategory.salary
    @State private var note = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section("Amount") {
                    HStack {
                        Text("$")
                            .font(.title)
                            .foregroundColor(.secondary)
                        
                        TextField("0.00", text: $amount)
                            .keyboardType(.decimalPad)
                            .font(.title)
                            .fontWeight(.semibold)
                    }
                }
                
                Section("Category") {
                    if isIncome {
                        Picker("Income Category", selection: $selectedIncomeCategory) {
                            ForEach(IncomeCategory.allCases, id: \.self) { category in
                                HStack {
                                    Text(category.icon)
                                    Text(category.rawValue)
                                }
                                .tag(category)
                            }
                        }
                        .pickerStyle(.wheel)
                    } else {
                        Picker("Expense Category", selection: $selectedCategory) {
                            ForEach(Category.allCases, id: \.self) { category in
                                HStack {
                                    Text(category.icon)
                                    Text(category.rawValue)
                                }
                                .tag(category)
                            }
                        }
                        .pickerStyle(.wheel)
                    }
                }
                
                Section("Note (Optional)") {
                    TextField("Add a note...", text: $note)
                }
            }
            .navigationTitle(isIncome ? "Add Income" : "Add Expense")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveTransaction()
                    }
                    .fontWeight(.semibold)
                    .disabled(amount.isEmpty || Double(amount) == nil)
                }
            }
        }
    }
    
    private func saveTransaction() {
        guard let amountValue = Double(amount), amountValue > 0 else { return }
        
        let transaction = Transaction(
            amount: amountValue,
            category: isIncome ? nil : selectedCategory,
            incomeCategory: isIncome ? selectedIncomeCategory : nil,
            isIncome: isIncome,
            date: Date(),
            note: note
        )
        
        viewModel.addTransaction(transaction)
        dismiss()
    }
}

// MARK: - Preview

#Preview {
    ContentView()
}
