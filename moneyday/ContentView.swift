import SwiftUI

struct ExpenseItem: Identifiable, Codable {
    let id = UUID()
    let amount: Double
    let category: String
    let date: Date
}

class Expenses: ObservableObject {
    @Published var items = [ExpenseItem]() {
        didSet {
            saveExpenses()
        }
    }
    
    init() {
        loadExpenses()
    }
    
    private func loadExpenses() {
        if let data = UserDefaults.standard.data(forKey: "expenses") {
            let decoder = JSONDecoder()
            if let decodedExpenses = try? decoder.decode([ExpenseItem].self, from: data) {
                self.items = decodedExpenses
                return
            }
        }
        self.items = []
    }
    
    private func saveExpenses() {
        let encoder = JSONEncoder()
        if let encoded = try? encoder.encode(items) {
            UserDefaults.standard.set(encoded, forKey: "expenses")
        }
    }
    
    func dailyTotal(for date: Date) -> Double {
        let total = items.reduce(0.0) { result, item in
            if Calendar.current.isDate(item.date, inSameDayAs: date) {
                return result + item.amount
            } else {
                return result
            }
        }
        return total
    }
    
    func monthlyTotal(for date: Date) -> Double {
        let startOfMonth = Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: date))!
        let endOfMonth = Calendar.current.date(byAdding: DateComponents(month: 1, day: -1), to: startOfMonth)!
        let total = items.filter { $0.date >= startOfMonth && $0.date <= endOfMonth }.reduce(0.0) { $0 + $1.amount }
        return total
    }
    
    func expensesForDate(_ date: Date) -> [ExpenseItem] {
        items.filter { Calendar.current.isDate($0.date, inSameDayAs: date) }
    }
}

struct ContentView: View {
    @ObservedObject var expenses = Expenses()
    @State private var showingAddExpense = false
    
    var body: some View {
        TabView {
            NavigationView {
                List {
                    ForEach(expenses.items) { item in
                        HStack {
                            VStack(alignment: .leading) {
                                Text("\(item.amount, specifier: "%.2f") €")
                                    .font(.headline)
                                Text(item.category)
                            }
                            Spacer()
                            Text("\(formattedDate(from: item.date))")
                                .font(.caption)
                        }
                    }
                    .onDelete(perform: removeItems)
                }
                .navigationBarTitle("Gastos")
                .navigationBarItems(trailing:
                    Button(action: {
                        self.showingAddExpense = true
                    }) {
                        Image(systemName: "plus")
                    }
                )
                .sheet(isPresented: $showingAddExpense) {
                    AddView(expenses: self.expenses)
                }
            }
            .tabItem {
                Image(systemName: "list.dash")
                Text("Gastos")
            }
            
            NavigationView {
                CalendarView(expenses: expenses)
            }
            .tabItem {
                Image(systemName: "calendar")
                Text("Calendario")
            }
        }
        .environment(\.locale, .init(identifier: "es"))
    }
    
    func removeItems(at offsets: IndexSet) {
        expenses.items.remove(atOffsets: offsets)
    }
    
    func formattedDate(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yyyy HH:mm"
        return formatter.string(from: date)
    }
}

struct CalendarView: View {
    @ObservedObject var expenses: Expenses
    @State private var selectedDate = Date()
    
    var body: some View {
        VStack {
            DatePicker("", selection: $selectedDate, displayedComponents: .date)
                .labelsHidden()
                .datePickerStyle(GraphicalDatePickerStyle())
            Text("Total diario: \(dailyTotalString(for: selectedDate)) €")
                .font(.headline)
                .padding()
            
            List {
                ForEach(expenses.expensesForDate(selectedDate)) { item in
                    HStack {
                        VStack(alignment: .leading) {
                            Text("\(item.amount, specifier: "%.2f") €")
                                .font(.headline)
                            Text(item.category)
                        }
                        Spacer()
                        Text("\(formattedDate(from: item.date))")
                            .font(.caption)
                    }
                }
            }
            
            Spacer()
        }
    }
    
    func dailyTotalString(for date: Date) -> String {
        let total = expenses.dailyTotal(for: date)
        return String(format: "%.2f", total)
    }
    
    func formattedDate(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yyyy HH:mm"
        return formatter.string(from: date)
    }
}

struct AddView: View {
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject var expenses: Expenses
    @State private var amount = ""
    @State private var category = ""
    @State private var selectedDate = Date()
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField("Cantidad", text: $amount)
                        .keyboardType(.numberPad)
                    TextField("Categoría", text: $category)
                    DatePicker("Fecha", selection: $selectedDate, displayedComponents: .date)
                        .labelsHidden()
                }
                
                Section {
                    Button("Guardar") {
                        if let actualAmount = Double(self.amount) {
                            let item = ExpenseItem(amount: actualAmount, category: self.category, date: self.selectedDate)
                            self.expenses.items.append(item)
                            self.presentationMode.wrappedValue.dismiss()
                        }
                    }
                }
            }
            .navigationBarTitle("Añadir Gasto")
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
