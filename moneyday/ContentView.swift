import SwiftUI

// Estructura que representa un elemento de gasto
struct ExpenseItem: Identifiable, Codable {
    let id = UUID()             // Identificador único del gasto
    let amount: Double          // Cantidad gastada
    let category: String        // Categoría del gasto
    let date: Date              // Fecha del gasto
}

// Clase que gestiona los gastos
class Expenses: ObservableObject {
    @Published var items = [ExpenseItem]() {   // Lista de gastos
        didSet {
            saveExpenses()                      // Guardar los cambios en los gastos
        }
    }
    
    init() {
        loadExpenses()                          // Cargar los gastos almacenados
    }
    
    // Cargar los gastos almacenados previamente
    private func loadExpenses() {
        if let data = UserDefaults.standard.data(forKey: "expenses") {
            let decoder = JSONDecoder()
            if let decodedExpenses = try? decoder.decode([ExpenseItem].self, from: data) {
                self.items = decodedExpenses
                return
            }
        }
        self.items = []                             // Si no hay gastos almacenados, iniciar con una lista vacía
    }
    
    // Guardar los gastos
    private func saveExpenses() {
        let encoder = JSONEncoder()
        if let encoded = try? encoder.encode(items) {
            UserDefaults.standard.set(encoded, forKey: "expenses")
        }
    }
    
    // Calcular el total diario de gastos para una fecha dada
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
    
    // Calcular el total mensual de gastos para una fecha dada
    func monthlyTotal(for date: Date) -> Double {
        let startOfMonth = Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: date))!
        let endOfMonth = Calendar.current.date(byAdding: DateComponents(month: 1, day: -1), to: startOfMonth)!
        let total = items.filter { $0.date >= startOfMonth && $0.date <= endOfMonth }.reduce(0.0) { $0 + $1.amount }
        return total
    }
    
    // Obtener los gastos para una fecha dada
    func expensesForDate(_ date: Date) -> [ExpenseItem] {
        items.filter { Calendar.current.isDate($0.date, inSameDayAs: date) }
    }
}

// Vista principal
struct ContentView: View {
    @ObservedObject var expenses = Expenses()         // Gastos observables
    @State private var showingAddExpense = false      // Estado para mostrar el formulario de añadir gasto
    
    var body: some View {
        // Vista de pestañas
        TabView {
            // Vista de lista de gastos
            NavigationView {
                List {
                    ForEach(expenses.items) { item in
                        // Elemento de la lista de gastos
                        HStack {
                            VStack(alignment: .leading) {
                                Text("\(item.amount, specifier: "%.2f") €")    // Cantidad del gasto
                                    .font(.headline)
                                Text(item.category)                             // Categoría del gasto
                            }
                            Spacer()
                            Text("\(formattedDate(from: item.date))")          // Fecha del gasto
                                .font(.caption)
                        }
                    }
                    .onDelete(perform: removeItems)                            // Eliminar gastos
                }
                .navigationBarTitle("Gastos")
                .navigationBarItems(trailing:
                    Button(action: {
                        self.showingAddExpense = true                          // Mostrar formulario de añadir gasto
                    }) {
                        Image(systemName: "plus")
                    }
                )
                .sheet(isPresented: $showingAddExpense) {
                    AddView(expenses: self.expenses)                          // Vista para añadir gasto
                }
            }
            .tabItem {
                Image(systemName: "list.dash")
                Text("Gastos")
            }
            
            // Vista de calendario
            NavigationView {
                CalendarView(expenses: expenses)                              // Vista de calendario
            }
            .tabItem {
                Image(systemName: "calendar")
                Text("Calendario")
            }
        }
        .environment(\.locale, .init(identifier: "es"))
    }
    
    // Eliminar gastos de la lista
    func removeItems(at offsets: IndexSet) {
        expenses.items.remove(atOffsets: offsets)
    }
    
    // Obtener fecha formateada como string
    func formattedDate(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yyyy HH:mm"
        return formatter.string(from: date)
    }
}

// Vista de calendario
struct CalendarView: View {
    @ObservedObject var expenses: Expenses       // Gastos observables
    @State private var selectedDate = Date()      // Fecha seleccionada
    
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
                    // Elemento de la lista de gastos
                    HStack {
                        VStack(alignment: .leading) {
                            Text("\(item.amount, specifier: "%.2f") €")    // Cantidad del gasto
                                .font(.headline)
                            Text(item.category)                             // Categoría del gasto
                        }
                        Spacer()
                        Text("\(formattedDate(from: item.date))")          // Fecha del gasto
                            .font(.caption)
                    }
                }
            }
            
            Spacer()
        }
    }
    
    // Obtener total diario de gastos como string
    func dailyTotalString(for date: Date) -> String {
        let total = expenses.dailyTotal(for: date)
        return String(format: "%.2f", total)
    }
    
    // Obtener fecha formateada como string
    func formattedDate(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yyyy HH:mm"
        return formatter.string(from: date)
    }
}

// Vista para añadir gasto
struct AddView: View {
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject var expenses: Expenses       // Gastos observables
    @State private var amount = ""                // Cantidad del gasto
    @State private var category = ""              // Categoría del gasto
    @State private var selectedDate = Date()      // Fecha del gasto
    
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
                            self.expenses.items.append(item)             // Añadir nuevo gasto a la lista
                            self.presentationMode.wrappedValue.dismiss() // Cerrar vista de añadir gasto
                        }
                    }
                }
            }
            .navigationBarTitle("Añadir Gasto")
        }
    }
}

// Estructura que proporciona una vista previa de ContentView
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()   // Muestra una vista previa de ContentView
    }
}
