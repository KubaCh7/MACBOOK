import PhotosUI
import SwiftUI
import UIKit

enum CatalogSort: String, CaseIterable {
    case popular, model, price
    var title: String {
        switch self {
        case .popular: return L.t("sortPopular")
        case .model: return L.t("sortModel")
        case .price: return L.t("sortPrice")
        }
    }
}

/// Lista podpowiedzi: wyszukiwarka i sortowanie (popularne / model / cena).
struct CatalogList: View {
    let items: [RemoteCatalogRow]
    var limit: Int? = nil
    let onPick: (RemoteCatalogRow) -> Void
    @State private var query = ""
    @State private var sort: CatalogSort = .popular

    private var list: [RemoteCatalogRow] {
        let words = query.lowercased().split(separator: " ").map(String.init)
        var out = items.filter { c in
            let hay = "\(c.name) \(c.spec)".lowercased()
            return words.allSatisfy { hay.contains($0) }
        }
        switch sort {
        case .popular: out.sort { $0.popularity > $1.popularity }
        case .model: out.sort { $0.name == $1.name ? $0.price_pln < $1.price_pln : $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        case .price: out.sort { $0.price_pln < $1.price_pln }
        }
        if let limit { return Array(out.prefix(limit)) }
        return out
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundStyle(Theme.muted)
                TextField(L.t("search"), text: $query)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }
            .padding(.horizontal, 12)
            .frame(height: 40)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.border, lineWidth: 1))

            Picker("", selection: $sort) {
                ForEach(CatalogSort.allCases, id: \.self) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            VStack(spacing: 0) {
                ForEach(list) { c in
                    Button {
                        Sound.shared.click()
                        onPick(c)
                    } label: {
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(c.name).font(.system(size: 15, weight: .medium)).foregroundStyle(Theme.text).lineLimit(1)
                                Text(c.spec).font(.system(size: 13)).foregroundStyle(Theme.muted).lineLimit(1)
                            }
                            Spacer(minLength: 8)
                            Text(Money.format(c.price_pln, lang: L.lang))
                                .font(.system(size: 15, weight: .bold).monospacedDigit())
                                .foregroundStyle(Theme.text)
                                .lineLimit(1)
                        }
                        .padding(.vertical, 10)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    if c.id != list.last?.id { Divider().overlay(Theme.rule) }
                }
            }
            Text(L.t("priceNote")).font(.system(size: 12)).foregroundStyle(Theme.muted)
        }
    }
}

/// Formularz nowego celu: nazwa, cena (można zmienić po wyborze podpowiedzi) i opcjonalne zdjęcie.
struct NewGoalForm: View {
    @EnvironmentObject var store: AppStore
    let prefill: RemoteCatalogRow?
    let submitTitle: String
    let onDone: () -> Void

    @State private var name = ""
    @State private var price = ""
    @State private var photo: Data?
    @State private var photoItem: PhotosPickerItem?
    @State private var error: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            LabeledField(label: L.t("goalName")) {
                TextField("", text: $name)
            }
            LabeledField(label: L.t("goalPrice")) {
                HStack {
                    TextField("0", text: $price).keyboardType(.decimalPad).font(.system(size: 18, weight: .bold).monospacedDigit())
                    Text("zł").foregroundStyle(Theme.muted)
                }
            }
            VStack(alignment: .leading, spacing: 8) {
                Text(L.t("addPhoto")).font(.system(size: 14, weight: .medium))
                if let photo, let img = UIImage(data: photo) {
                    Color.clear
                        .aspectRatio(4 / 3, contentMode: .fit)
                        .overlay(Image(uiImage: img).resizable().scaledToFill())
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                PhotosPicker(selection: $photoItem, matching: .images) {
                    Text(photo == nil ? L.t("fromGallery") : L.t("addPhoto"))
                }
                .buttonStyle(SecondaryButtonStyle())
            }
            if let error {
                Text(error).font(.system(size: 13)).foregroundStyle(Theme.negative)
            }
            Button(submitTitle) { submit() }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || price.isEmpty)
        }
        .onAppear {
            if let p = prefill, name.isEmpty {
                name = p.name
                price = String(Int(p.price_pln))
            }
        }
        .onChange(of: photoItem) { _, item in
            guard let item else { return }
            Task { photo = try? await item.loadTransferable(type: Data.self) }
        }
    }

    private func submit() {
        guard let value = parseAmount(price), value > 0 else {
            error = L.t("amountInvalid")
            return
        }
        store.createGoal(name: name, price: value, catalogID: prefill?.id, photo: photo)
        onDone()
    }
}

struct LabeledField<C: View>: View {
    let label: String
    @ViewBuilder var content: C
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.system(size: 14, weight: .medium))
            content
                .padding(.horizontal, 12)
                .frame(minHeight: 44)
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.border, lineWidth: 1))
        }
    }
}

func parseAmount(_ s: String) -> Double? {
    let clean = s.replacingOccurrences(of: " ", with: "")
        .replacingOccurrences(of: "\u{00a0}", with: "")
        .replacingOccurrences(of: "zł", with: "")
        .replacingOccurrences(of: ",", with: ".")
    guard let v = Double(clean), v.isFinite else { return nil }
    return (v * 100).rounded() / 100
}

/// Pierwsze uruchomienie: wybór MacBooka albo własny cel.
struct OnboardingView: View {
    @EnvironmentObject var store: AppStore
    @State private var picked: RemoteCatalogRow?
    @State private var custom = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 12) {
                    AppMark(size: 36)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(L.t("onbTitle")).font(.system(size: 22, weight: .semibold)).lineLimit(1).minimumScaleFactor(0.8)
                        Text(L.t("onbSub")).font(.system(size: 15)).foregroundStyle(Theme.muted).fixedSize(horizontal: false, vertical: true)
                    }
                }
                Card {
                    if picked != nil || custom {
                        NewGoalForm(prefill: picked, submitTitle: L.t("startSaving")) { store.markOnboarded() }
                        Button(L.t("back")) { picked = nil; custom = false }
                            .buttonStyle(SecondaryButtonStyle())
                    } else {
                        CatalogList(items: store.catalog) { picked = $0 }
                        Button(L.t("customGoal")) { custom = true }
                            .buttonStyle(SecondaryButtonStyle())
                    }
                }
                LegalLinks()
            }
            .padding(16)
        }
        .scrollDismissesKeyboard(.interactively)
        .screenBackground()
    }
}

/// Arkusz „Nowy cel” z zakładki Cele.
struct NewGoalSheet: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var picked: RemoteCatalogRow?
    @State private var custom = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if picked != nil || custom {
                        NewGoalForm(prefill: picked, submitTitle: L.t("addGoal")) { dismiss() }
                        Button(L.t("back")) { picked = nil; custom = false }
                            .buttonStyle(SecondaryButtonStyle())
                    } else {
                        CatalogList(items: store.catalog) { picked = $0 }
                        Button(L.t("customGoal")) { custom = true }
                            .buttonStyle(SecondaryButtonStyle())
                    }
                }
                .padding(16)
            }
            .screenBackground()
            .navigationTitle(L.t("newGoal"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L.t("cancel")) { dismiss() }
                }
            }
        }
    }
}
