import SwiftData
import SwiftUI

/// Wpłata / wypłata: kwota, szybkie kwoty, data, notatka.
struct DepositSheet: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss
    let goalID: UUID
    let existing: DepositEntity?

    @State private var withdrawal = false
    @State private var amount = ""
    @State private var date = Date()
    @State private var note = ""
    @State private var error: String?
    @State private var showDelete = false

    private let quick: [Double] = [50, 100, 200, 500]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("", selection: $withdrawal) {
                        Text(L.t("deposit")).tag(false)
                        Text(L.t("withdrawal")).tag(true)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .onChange(of: withdrawal) { _, _ in Sound.shared.tab(); error = nil }

                    HStack {
                        TextField("0", text: $amount)
                            .keyboardType(.decimalPad)
                            .font(.system(size: 28, weight: .bold).monospacedDigit())
                        Text("zł").foregroundStyle(Theme.muted)
                    }
                    // każdy przycisk ma własny styl — inaczej w wierszu Form odpaliłyby się wszystkie
                    HStack(spacing: 8) {
                        ForEach(quick, id: \.self) { q in
                            Button("+\(Int(q)) zł") { add(q) }
                                .buttonStyle(QuickAmountButtonStyle())
                        }
                    }
                    if let error {
                        Text(error).font(.system(size: 13)).foregroundStyle(Theme.negative)
                    } else if withdrawal {
                        Text(L.t("maxWithdraw", ["max": Money.format(available, lang: L.lang)]))
                            .font(.system(size: 13)).foregroundStyle(Theme.muted)
                    }
                }
                Section {
                    DatePicker(L.t("date"), selection: $date, displayedComponents: .date)
                        .environment(\.locale, L.locale)
                    TextField(L.t("note"), text: $note)
                }
                if existing != nil {
                    Section {
                        Button(L.t("delete"), role: .destructive) { showDelete = true }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.ground)
            .navigationTitle(existing == nil ? L.t("newDeposit") : L.t("editDeposit"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(L.t("cancel")) { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button(L.t("save")) { save() } }
            }
            .confirmationDialog(L.t("delete"), isPresented: $showDelete, titleVisibility: .visible) {
                Button(L.t("delete"), role: .destructive) { remove() }
            }
        }
        .onAppear {
            if let d = existing {
                withdrawal = d.amount < 0
                amount = format(abs(d.amount))
                date = Day.date(d.day)
                note = d.note ?? ""
            }
        }
    }

    private var available: Double {
        balance(of: existing?.goalID ?? goalID, in: store.allDeposits(), excluding: existing?.id)
    }

    private func format(_ v: Double) -> String {
        let s = v.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(v)) : String(format: "%.2f", v)
        return L.lang == "pl" ? s.replacingOccurrences(of: ".", with: ",") : s
    }

    private func add(_ q: Double) {
        Sound.shared.click()
        let cur = parseAmount(amount) ?? 0
        amount = format(cur + q)
        error = nil
    }

    private func save() {
        guard let v = parseAmount(amount), v > 0 else {
            error = L.t("amountInvalid")
            return
        }
        do {
            try store.saveDeposit(existing: existing, goalID: existing?.goalID ?? goalID, amount: withdrawal ? -v : v,
                                  day: Day.string(date), note: note)
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func remove() {
        guard let d = existing else { return }
        do {
            try store.deleteDeposit(d)
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
    }
}

/// Zmiana ceny w dwóch krokach: nowa cena → „z X na Y”, różnica, ile brakuje → „Tak, zmień cenę”.
struct PriceSheet: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss
    let goal: GoalEntity
    let saved: Double

    @State private var step = 1
    @State private var value = ""
    @State private var error: String?

    private var newPrice: Double { parseAmount(value) ?? 0 }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                if step == 1 {
                    Text("\(goal.name) · \(L.t("price")) \(Money.format(goal.targetAmount, lang: L.lang))")
                        .font(.system(size: 15)).foregroundStyle(Theme.muted)
                    LabeledField(label: L.t("newPrice")) {
                        HStack {
                            TextField("0", text: $value).keyboardType(.decimalPad)
                                .font(.system(size: 20, weight: .bold).monospacedDigit())
                            Text("zł").foregroundStyle(Theme.muted)
                        }
                    }
                    if let error { Text(error).font(.system(size: 13)).foregroundStyle(Theme.negative) }
                    Button(L.t("next")) {
                        guard newPrice > 0 else { error = L.t("amountInvalid"); return }
                        Sound.shared.click()
                        step = 2
                    }
                    .buttonStyle(PrimaryButtonStyle())
                } else {
                    Text(L.t("confirmPriceChange", ["from": Money.format(goal.targetAmount, lang: L.lang), "to": Money.format(newPrice, lang: L.lang)]))
                        .font(.system(size: 17, weight: .medium))
                        .fixedSize(horizontal: false, vertical: true)
                    Card {
                        row(L.t("difference"), Money.format(newPrice - goal.targetAmount, lang: L.lang, sign: true))
                        Divider().overlay(Theme.rule)
                        row(L.t("saved"), Money.format(saved, lang: L.lang))
                        Divider().overlay(Theme.rule)
                        row(L.t("willBeLeft"), Money.format(max(0, newPrice - saved), lang: L.lang))
                    }
                    HStack(spacing: 8) {
                        Button(L.t("back")) { step = 1 }.buttonStyle(SecondaryButtonStyle())
                        Button(L.t("yesChange")) {
                            store.changePrice(goal, to: newPrice)
                            Sound.shared.click()
                            dismiss()
                        }
                        .buttonStyle(PrimaryButtonStyle())
                    }
                }
                Spacer()
            }
            .padding(16)
            .screenBackground()
            .navigationTitle(L.t("changePrice"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(L.t("cancel")) { dismiss() } }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).foregroundStyle(Theme.muted)
            Spacer()
            Text(value).fontWeight(.bold).monospacedDigit()
        }
        .font(.system(size: 15))
        .lineLimit(1)
    }
}
