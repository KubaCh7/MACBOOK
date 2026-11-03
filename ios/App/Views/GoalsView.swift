import SwiftData
import SwiftUI
import UIKit

struct GoalsView: View {
    @EnvironmentObject var store: AppStore
    let goals: [GoalEntity]
    let onOpen: (UUID) -> Void
    @Query private var allDeposits: [DepositEntity]
    @State private var adding = false
    @State private var editing: GoalEntity?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Card {
                    CardTitle(text: L.t("yourGoals"))
                    VStack(spacing: 0) {
                        ForEach(goals) { g in
                            goalRow(g)
                            if g.id != goals.last?.id { Divider().overlay(Theme.rule) }
                        }
                    }
                    Button(L.t("addGoal")) { adding = true }
                        .buttonStyle(PrimaryButtonStyle())
                }
                Card {
                    CardTitle(text: L.t("suggestions"))
                    CatalogList(items: store.catalog, limit: 4) { c in
                        store.createGoal(name: c.name, price: c.price_pln, catalogID: c.id)
                    }
                }
            }
            .padding(16)
        }
        .screenBackground()
        .navigationTitle(L.t("tabGoals"))
        .sheet(isPresented: $adding) { NewGoalSheet() }
        .sheet(item: $editing) { g in GoalEditSheet(goal: g) }
    }

    private func goalRow(_ g: GoalEntity) -> some View {
        let s = GoalStats(target: g.targetAmount, deposits: allDeposits.filter { $0.goalID == g.id })
        return HStack(spacing: 12) {
            Button { onOpen(g.id) } label: {
                HStack(spacing: 12) {
                    Group {
                        if let data = g.photoData, let img = UIImage(data: data) {
                            PositionedImage(image: img, position: PhotoPosition(string: g.photoPosition))
                        } else {
                            Image("Laptop").renderingMode(.template).resizable().scaledToFit().padding(18).foregroundStyle(Theme.muted)
                        }
                    }
                    .frame(width: 80, height: 60)
                    .background(Theme.raised)
                    .clipShape(RoundedRectangle(cornerRadius: 6))

                    VStack(alignment: .leading, spacing: 4) {
                        Text(g.name).font(.system(size: 15, weight: .medium)).foregroundStyle(Theme.text).lineLimit(1)
                        Text("\(Money.format(s.saved, lang: L.lang)) \(L.t("ofPrice", ["price": Money.format(s.target, lang: L.lang)]))")
                            .font(.system(size: 13).monospacedDigit()).foregroundStyle(Theme.muted).lineLimit(1).minimumScaleFactor(0.8)
                        ProgressBar(ratio: s.ratio, height: 5)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button {
                if !g.isDefault { store.setDefault(g); Sound.shared.click() }
            } label: {
                Image(systemName: g.isDefault ? "star.fill" : "star")
                    .font(.system(size: 17))
                    .foregroundStyle(g.isDefault ? Theme.text : Theme.muted)
                    .frame(width: 36, height: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(g.isDefault ? L.t("main") : L.t("setMain"))

            Button { editing = g } label: {
                Image(systemName: "pencil").font(.system(size: 16)).foregroundStyle(Theme.muted).frame(width: 36, height: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(L.t("edit"))
        }
        .padding(.vertical, 8)
    }
}

/// Edycja celu: nazwa, zdjęcie z kadrem, cena tylko przez „Zmień cenę”, gwiazdka, usunięcie.
struct GoalEditSheet: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss
    let goal: GoalEntity
    @Query private var allDeposits: [DepositEntity]
    @State private var name = ""
    @State private var changePrice = false
    @State private var confirmDelete = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    LabeledField(label: L.t("goalName")) { TextField("", text: $name) }
                    VStack(alignment: .leading, spacing: 6) {
                        Text(L.t("price")).font(.system(size: 14, weight: .medium))
                        HStack(spacing: 8) {
                            Text(Money.format(goal.targetAmount, lang: L.lang))
                                .font(.system(size: 18, weight: .bold).monospacedDigit())
                                .lineLimit(1)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Button(L.t("changePrice")) { changePrice = true }
                                .buttonStyle(SecondaryButtonStyle())
                                .frame(width: 150)
                        }
                    }
                    PhotoCard(goal: goal)
                    Button(goal.isDefault ? L.t("main") : L.t("setMain")) { store.setDefault(goal) }
                        .buttonStyle(SecondaryButtonStyle())
                        .disabled(goal.isDefault)
                    Button(L.t("deleteGoal")) { confirmDelete = true }
                        .buttonStyle(SecondaryButtonStyle(destructive: true))
                }
                .padding(16)
            }
            .screenBackground()
            .navigationTitle(L.t("editGoal"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(L.t("cancel")) { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L.t("save")) {
                        if !name.trimmingCharacters(in: .whitespaces).isEmpty, name != goal.name { store.rename(goal, to: name) }
                        dismiss()
                    }
                }
            }
            .confirmationDialog(L.t("deleteGoalQ", ["name": goal.name]), isPresented: $confirmDelete, titleVisibility: .visible) {
                Button(L.t("deleteGoal"), role: .destructive) {
                    store.deleteGoal(goal)
                    dismiss()
                }
            }
            .sheet(isPresented: $changePrice) {
                PriceSheet(goal: goal, saved: balance(of: goal.id, in: allDeposits))
            }
        }
        .onAppear { name = goal.name }
    }
}
