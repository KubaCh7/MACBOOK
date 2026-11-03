import SwiftData
import SwiftUI

struct DepositsView: View {
    @EnvironmentObject var store: AppStore
    let goal: GoalEntity
    let goals: [GoalEntity]
    @Binding var goalID: UUID?
    @Query private var allDeposits: [DepositEntity]
    @State private var addDeposit = false
    @State private var editDeposit: DepositEntity?

    private var deposits: [DepositEntity] { allDeposits.filter { $0.goalID == goal.id && $0.deletedAt == nil } }

    private var groups: [(key: String, date: Date, items: [DepositEntity], net: Double)] {
        let sorted = deposits.sorted { $0.day == $1.day ? $0.createdAt > $1.createdAt : $0.day > $1.day }
        var order: [String] = []
        var map: [String: [DepositEntity]] = [:]
        for d in sorted {
            let k = String(d.day.prefix(7))
            if map[k] == nil { order.append(k) }
            map[k, default: []].append(d)
        }
        return order.map { k in
            let items = map[k] ?? []
            return (k, Day.date("\(k)-01"), items, ((items.reduce(0) { $0 + $1.amount }) * 100).rounded() / 100)
        }
    }

    var body: some View {
        let s = GoalStats(target: goal.targetAmount, deposits: deposits)
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("\(goal.name) · \(L.plural(s.depositCount, pl: ("wpłata", "wpłaty", "wpłat"), en: ("deposit", "deposits"))) · \(L.plural(s.withdrawalCount, pl: ("wypłata", "wypłaty", "wypłat"), en: ("withdrawal", "withdrawals")))")
                    .font(.system(size: 15)).foregroundStyle(Theme.muted).lineLimit(1).minimumScaleFactor(0.8)

                Card {
                    CardTitle(text: L.t("monthly"))
                    MonthlyChart(stats: s)
                }

                Card {
                    CardTitle(text: L.t("summary"))
                    VStack(spacing: 0) {
                        kv(L.t("saved"), Money.format(s.saved, lang: L.lang), bold: true)
                        kv(L.t("totalIn"), Money.format(s.totalIn, lang: L.lang))
                        kv(L.t("totalOut"), Money.format(s.totalOut, lang: L.lang), negative: s.totalOut < 0)
                        kv(L.t("avgDeposit"), s.depositCount > 0 ? Money.format(s.avgDeposit, lang: L.lang) : "—")
                        kv(L.t("depositCount"), "\(s.depositCount)")
                        kv(L.t("largest"), s.depositCount > 0 ? Money.format(s.largest, lang: L.lang) : "—", last: true)
                    }
                }

                Card {
                    CardTitle(text: L.t("history"))
                    if groups.isEmpty {
                        Text(L.t("noDeposits")).font(.system(size: 14)).foregroundStyle(Theme.muted)
                        Button(L.t("addDeposit")) { addDeposit = true }.buttonStyle(PrimaryButtonStyle())
                    } else {
                        VStack(spacing: 0) {
                            ForEach(groups, id: \.key) { g in
                                HStack {
                                    Text(L.monthYear(g.date)).font(.system(size: 15, weight: .semibold))
                                    Spacer()
                                    Text(Money.format(g.net, lang: L.lang, sign: g.net > 0))
                                        .font(.system(size: 14, weight: .semibold).monospacedDigit())
                                        .foregroundStyle(Theme.muted)
                                }
                                .lineLimit(1)
                                .padding(.top, 14)
                                .padding(.bottom, 6)
                                Divider().overlay(Theme.border)
                                ForEach(g.items) { d in
                                    Button { editDeposit = d } label: { DepositRowView(deposit: d) }
                                        .buttonStyle(.plain)
                                    Divider().overlay(Theme.rule)
                                }
                            }
                        }
                    }
                }
            }
            .padding(16)
        }
        .screenBackground()
        .navigationTitle(L.t("tabDeposits"))
        .refreshable { await store.syncNow() }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                GoalSwitcher(goals: goals, goalID: $goalID, current: goal)
            }
            ToolbarItem(placement: .primaryAction) {
                Button { addDeposit = true } label: { Image(systemName: "plus") }
                    .accessibilityLabel(L.t("addDeposit"))
            }
        }
        .sheet(isPresented: $addDeposit) { DepositSheet(goalID: goal.id, existing: nil) }
        .sheet(item: $editDeposit) { d in DepositSheet(goalID: goal.id, existing: d) }
    }

    private func kv(_ label: String, _ value: String, bold: Bool = false, negative: Bool = false, last: Bool = false) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text(label).foregroundStyle(Theme.muted)
                Spacer()
                Text(value)
                    .fontWeight(value == "—" ? .regular : (bold || value.contains("zł") ? .bold : .regular))
                    .monospacedDigit()
                    .foregroundStyle(negative ? Theme.negative : (value == "—" ? Theme.muted : Theme.text))
            }
            .font(.system(size: 15))
            .lineLimit(1)
            .padding(.vertical, 10)
            if !last { Divider().overlay(Theme.rule) }
        }
    }
}
