import SwiftData
import SwiftUI
import UIKit

struct OverviewView: View {
    @EnvironmentObject var store: AppStore
    let goal: GoalEntity
    let goals: [GoalEntity]
    @Binding var goalID: UUID?
    @Query private var allDeposits: [DepositEntity]

    @State private var addDeposit = false
    @State private var editDeposit: DepositEntity?
    @State private var changePrice = false

    private var deposits: [DepositEntity] { allDeposits.filter { $0.goalID == goal.id && $0.deletedAt == nil } }
    private var stats: GoalStats { GoalStats(target: goal.targetAmount, deposits: deposits) }
    private var recent: [DepositEntity] {
        Array(deposits.sorted { $0.day == $1.day ? $0.createdAt > $1.createdAt : $0.day > $1.day }.prefix(5))
    }

    var body: some View {
        let s = stats
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text(s.forecastSentence(lang: L.lang))
                    .font(.system(size: 15))
                    .foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)

                UpdateBanner()

                // Postęp
                Card {
                    HStack {
                        CardTitle(text: L.t("progress"))
                        Spacer()
                        Button(L.t("changePrice")) { changePrice = true }
                            .buttonStyle(SecondaryButtonStyle())
                            .frame(width: 130)
                    }
                    Figure(label: L.t("saved"), value: Money.format(s.saved, lang: L.lang), size: 30)
                    HStack(alignment: .top) {
                        Figure(label: L.t("price"), value: Money.format(s.target, lang: L.lang))
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Figure(label: L.t("left"), value: Money.format(s.left, lang: L.lang))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    VStack(spacing: 6) {
                        ProgressBar(ratio: s.ratio)
                        HStack {
                            Text("\(String(format: "%.1f", s.ratio * 100).replacingOccurrences(of: ".", with: L.lang == "pl" ? "," : "."))%")
                            Spacer()
                            Text(Money.format(s.target, lang: L.lang))
                        }
                        .font(.system(size: 12).monospacedDigit())
                        .foregroundStyle(Theme.muted)
                    }
                    StatStrip(stats: s)
                }

                Card(padding: 12) { PhotoCard(goal: goal) }

                Card {
                    CardTitle(text: L.t("cumulative"))
                    CumulativeChart(stats: s)
                }

                Card {
                    CardTitle(text: L.t("recent"))
                    if recent.isEmpty {
                        Text(L.t("noDeposits")).font(.system(size: 14)).foregroundStyle(Theme.muted)
                        Button(L.t("addDeposit")) { addDeposit = true }.buttonStyle(PrimaryButtonStyle())
                    } else {
                        VStack(spacing: 0) {
                            ForEach(recent) { d in
                                Button { editDeposit = d } label: { DepositRowView(deposit: d) }
                                    .buttonStyle(.plain)
                                if d.id != recent.last?.id { Divider().overlay(Theme.rule) }
                            }
                        }
                    }
                }
            }
            .padding(16)
        }
        .screenBackground()
        .navigationTitle(goal.name)
        .navigationBarTitleDisplayMode(.large)
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
        .sheet(isPresented: $changePrice) { PriceSheet(goal: goal, saved: s.saved) }
    }
}

/// Cztery liczby w jednym podzielonym pasku (2 × 2 na telefonie).
struct StatStrip: View {
    let stats: GoalStats

    var body: some View {
        let cells: [(String, String, Bool)] = [
            (L.t("thisMonth"), Money.format(stats.thisMonth, lang: L.lang, sign: stats.thisMonth > 0), true),
            (L.t("pace"), Money.format(stats.pace.rounded(), lang: L.lang) + " " + L.t("perMonth"), true),
            (L.t("avgDeposit"), stats.depositCount > 0 ? Money.format(stats.avgDeposit, lang: L.lang) : "—", true),
            (L.t("depositCount"), "\(stats.depositCount)", false),
        ]
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                cell(cells[0]); Divider().overlay(Theme.border); cell(cells[1])
            }
            Divider().overlay(Theme.border)
            HStack(spacing: 0) {
                cell(cells[2]); Divider().overlay(Theme.border); cell(cells[3])
            }
        }
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.border, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func cell(_ c: (String, String, Bool)) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(c.0).font(.system(size: 12)).foregroundStyle(Theme.muted).lineLimit(1).minimumScaleFactor(0.8)
            Text(c.1).font(.system(size: 16, weight: c.2 ? .bold : .medium).monospacedDigit()).lineLimit(1).minimumScaleFactor(0.7)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Wiersz wpłaty: notatka i data, kwota po prawej (wypłaty na czerwono z minusem).
struct DepositRowView: View {
    let deposit: DepositEntity
    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(deposit.note ?? (deposit.amount < 0 ? L.t("withdrawal") : L.t("deposit")))
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(deposit.note == nil ? Theme.muted : Theme.text)
                    .lineLimit(1)
                Text(L.dayMonth(deposit.day)).font(.system(size: 13)).foregroundStyle(Theme.muted).lineLimit(1)
            }
            Spacer(minLength: 8)
            Text(Money.format(deposit.amount, lang: L.lang, sign: true))
                .font(.system(size: 15, weight: .bold).monospacedDigit())
                .foregroundStyle(deposit.amount < 0 ? Theme.negative : Theme.text)
                .lineLimit(1)
        }
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }
}
