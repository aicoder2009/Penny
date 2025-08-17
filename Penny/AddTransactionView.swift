//
//  AddTransactionView.swift
//  Penny
//
//  Created by Kiro on 8/17/25.
//

import SwiftUI

struct AddTransactionView: View {
    let isIncome: Bool
    @ObservedObject var viewModel: BudgetViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var amount: String
    @State private var selectedCategory: Category?
    @State private var selectedIncomeCategory: IncomeCategory?
    @State private var note: String = ""
    @State private var date: Date = Date()
    
    init(isIncome: Bool, viewModel: BudgetViewModel, prefilledAmount: Double? = nil, prefilledCategory: Category? = nil) {
        self.isIncome = isIncome
        self.viewModel = viewModel
        self._amount = State(initialValue: prefilledAmount != nil ? String(format: "%.2f", prefilledAmount!) : "")
        self._selectedCategory = State(initialValue: prefilledCategory)
        self._selectedIncomeCategory = State(initialValue: isIncome ? .salary : nil)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("Amount") {
                    HStack {
                        Text("$")
                            .font(.title2)
                            .foregroundColor(.secondary)
                        TextField("0.00", text: $amount)
                            .keyboardType(.decimalPad)
                            .font(.title2)
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
                                .tag(category as IncomeCategory?)
                            }
                        }
                    } else {
                        Picker("Expense Category", selection: $selectedCategory) {
                            ForEach(Category.allCases, id: \.self) { category in
                                HStack {
                                    Text(category.icon)
                                    Text(category.rawValue)
                                }
                                .tag(category as Category?)
                            }
                        }
                    }
                }
                
                Section("Details") {
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                    
                    TextField("Note (optional)", text: $note)
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
                    .disabled(!isValidTransaction)
                }
            }
        }
    }
    
    private var isValidTransaction: Bool {
        guard let amountValue = Double(amount), amountValue > 0 else { return false }
        
        if isIncome {
            return selectedIncomeCategory != nil
        } else {
            return selectedCategory != nil
        }
    }
    
    private func saveTransaction() {
        guard let amountValue = Double(amount), amountValue > 0 else { return }
        
        let transaction = Transaction(
            amount: amountValue,
            category: selectedCategory,
            incomeCategory: selectedIncomeCategory,
            isIncome: isIncome,
            date: date,
            note: note
        )
        
        viewModel.addTransaction(transaction)
        dismiss()
    }
}

#Preview {
    AddTransactionView(isIncome: false, viewModel: BudgetViewModel())
}