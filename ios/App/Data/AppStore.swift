import Foundation
import SwiftData
import SwiftUI
import UIKit
import WidgetKit

enum AppMode: String {
    case signedOut, local, remote
}

/// Stan aplikacji i wszystkie operacje na danych. Dane leżą w SwiftData (offline),
/// a przy koncie są wysyłane do Supabase i pobierane z powrotem.
@MainActor
final class AppStore: ObservableObject {
    @Published var mode: AppMode = .signedOut
    @Published var email: String = ""
    @Published var displayName: String = ""
    @Published var onboarded: Bool = false
    @Published var catalog: [RemoteCatalogRow] = CatalogFallback.items
    @Published var latestBuild: Int = 0
    @Published var syncing = false
    @Published var lastSync: Date?
    @Published var syncError: String?

    let context: ModelContext
    private let api = SupabaseAPI.shared
    private var defaults: UserDefaults { L.defaults }
    private var syncTask: Task<Void, Never>?
    private var pendingResync = false

    var currentBuild: Int { Int((Bundle.main.object(forInfoDictionaryKey: "AppBuild") as? String) ?? "") ?? 0 }
    var updateAvailable: Bool { latestBuild > currentBuild && currentBuild > 0 }
    var canUseAccounts: Bool { api.isConfigured }

    init(context: ModelContext) {
        self.context = context
        displayName = defaults.string(forKey: "displayName") ?? ""
        onboarded = defaults.bool(forKey: "onboarded")
        if let s = api.session {
            mode = .remote
            email = s.email
        } else if defaults.bool(forKey: "localMode") || !api.isConfigured {
            mode = .local
        }
        if let ts = defaults.object(forKey: "lastSync") as? Date { lastSync = ts }
    }

    // MARK: pobieranie lokalne

    func allGoals() -> [GoalEntity] {
        ((try? context.fetch(FetchDescriptor<GoalEntity>())) ?? []).sorted { $0.createdAt < $1.createdAt }
    }

    func goals() -> [GoalEntity] { allGoals().filter { $0.deletedAt == nil } }

    func allDeposits() -> [DepositEntity] { (try? context.fetch(FetchDescriptor<DepositEntity>())) ?? [] }

    func deposits(for goalID: UUID) -> [DepositEntity] {
        allDeposits().filter { $0.goalID == goalID && $0.deletedAt == nil }
    }

    func defaultGoal() -> GoalEntity? {
        let g = goals()
        return g.first(where: { $0.isDefault }) ?? g.first
    }

    // MARK: logowanie

    func signIn(email: String, password: String) async throws {
        try await api.signIn(email: email, password: password)
        enterRemote()
    }

    func signUp(email: String, password: String, name: String) async throws {
        try await api.signUp(email: email, password: password, name: name)
        displayName = name
        defaults.set(name, forKey: "displayName")
        enterRemote()
    }

    private func enterRemote() {
        defaults.set(false, forKey: "localMode")
        email = api.session?.email ?? ""
        // dane z trybu bez konta przechodzą na konto
        for g in allGoals() { g.needsSync = true; if g.photoData != nil && (g.photoURL == nil || !(g.photoURL!.hasPrefix("http"))) { g.photoNeedsUpload = true } }
        for d in allDeposits() { d.needsSync = true }
        save()
        mode = .remote
        defaults.set(nil, forKey: "lastPull")
        syncSoon()
    }

    func useLocal() {
        defaults.set(true, forKey: "localMode")
        mode = .local
        refreshWidget()
    }

    func signOut() {
        api.signOut()
        wipeLocal()
        defaults.set(false, forKey: "localMode")
        mode = .signedOut
    }

    private func wipeLocal() {
        for g in allGoals() { context.delete(g) }
        for d in allDeposits() { context.delete(d) }
        save()
        displayName = ""
        onboarded = false
        defaults.set("", forKey: "displayName")
        defaults.set(false, forKey: "onboarded")
        defaults.set(nil, forKey: "lastPull")
        refreshWidget()
    }

    func deleteAccount() async throws {
        if mode == .remote, let uid = api.userID {
            let paths = (try? await api.listPhotos(prefix: uid)) ?? []
            try? await api.removePhotos(paths: paths)
            try await api.rpc("delete_account")
        }
        api.signOut()
        wipeLocal()
        defaults.set(false, forKey: "localMode")
        mode = .signedOut
    }

    // MARK: profil

    func setDisplayName(_ name: String) {
        displayName = name
        defaults.set(name, forKey: "displayName")
        guard mode == .remote, let uid = api.userID else { return }
        Task { try? await api.patch("/rest/v1/profiles?id=eq.\(uid)", json: ["display_name": name]) }
    }

    func markOnboarded() {
        onboarded = true
        defaults.set(true, forKey: "onboarded")
        guard mode == .remote, let uid = api.userID else { return }
        Task { try? await api.patch("/rest/v1/profiles?id=eq.\(uid)", json: ["onboarded": true]) }
    }

    // MARK: cele

    @discardableResult
    func createGoal(name: String, price: Double, catalogID: String?, photo: Data? = nil, photoLink: String? = nil) -> GoalEntity {
        let first = goals().isEmpty
        let g = GoalEntity(name: name.trimmingCharacters(in: .whitespaces), targetAmount: price, catalogID: catalogID, isDefault: first)
        context.insert(g)
        if let photo { g.photoData = Self.jpeg(photo); g.photoNeedsUpload = true }
        if let photoLink { g.photoURL = photoLink }
        changed()
        Sound.shared.chord()
        return g
    }

    func rename(_ g: GoalEntity, to name: String) {
        g.name = name.trimmingCharacters(in: .whitespaces)
        touch(g)
    }

    func changePrice(_ g: GoalEntity, to price: Double) {
        g.targetAmount = price
        touch(g)
    }

    func setPhoto(_ g: GoalEntity, data: Data?, link: String? = nil) {
        if data == nil, link == nil, let old = g.photoURL, !old.hasPrefix("http"), mode == .remote {
            Task { try? await api.removePhotos(paths: [old]) }
        }
        g.photoData = data.map { Self.jpeg($0) }
        g.photoPosition = "50% 50%"
        if let link {
            g.photoURL = link
            g.photoNeedsUpload = false
        } else if data != nil {
            g.photoNeedsUpload = true
        } else {
            g.photoURL = nil
            g.photoNeedsUpload = false
        }
        touch(g)
    }

    func setPhotoPosition(_ g: GoalEntity, _ p: PhotoPosition) {
        guard g.photoPosition != p.string else { return }
        g.photoPosition = p.string
        touch(g)
    }

    func setDefault(_ g: GoalEntity) {
        for x in goals() where x.isDefault != (x.id == g.id) {
            x.isDefault = (x.id == g.id)
            x.updatedAt = Date()
            x.needsSync = true
        }
        changed()
        if mode == .remote {
            let id = g.id.uuidString.lowercased()
            Task {
                await syncNow()
                try? await api.rpc("set_default_goal", params: ["p_goal_id": id])
            }
        }
    }

    func deleteGoal(_ g: GoalEntity) {
        let now = Date()
        if let old = g.photoURL, !old.hasPrefix("http"), mode == .remote {
            Task { try? await api.removePhotos(paths: [old]) }
        }
        g.deletedAt = now
        g.photoURL = nil
        g.photoData = nil
        let wasDefault = g.isDefault
        g.isDefault = false
        touch(g, notify: false)
        for d in deposits(for: g.id) { d.deletedAt = now; d.updatedAt = now; d.needsSync = true }
        if wasDefault, let next = goals().first { next.isDefault = true; touch(next, notify: false) }
        changed()
        Sound.shared.remove()
    }

    private func touch(_ g: GoalEntity, notify: Bool = true) {
        g.updatedAt = Date()
        g.needsSync = true
        if notify { changed() }
    }

    // MARK: wpłaty

    enum DepositError: LocalizedError {
        case exceedsBalance(Double)
        var errorDescription: String? {
            if case let .exceedsBalance(max) = self { return L.t("maxWithdraw", ["max": Money.format(max, lang: L.lang)]) }
            return nil
        }
    }

    func saveDeposit(existing: DepositEntity?, goalID: UUID, amount: Double, day: String, note: String?) throws {
        let available = balance(of: goalID, in: allDeposits(), excluding: existing?.id)
        if amount < 0 && available + amount < -0.001 { throw DepositError.exceedsBalance(available) }
        let cleanNote = note?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let d = existing {
            d.amount = amount
            d.day = day
            d.note = (cleanNote?.isEmpty ?? true) ? nil : cleanNote
            d.updatedAt = Date()
            d.needsSync = true
        } else {
            context.insert(DepositEntity(goalID: goalID, amount: amount, day: day, note: (cleanNote?.isEmpty ?? true) ? nil : cleanNote))
        }
        changed()
        if amount < 0 { Sound.shared.withdraw() } else { Sound.shared.coin() }
    }

    func deleteDeposit(_ d: DepositEntity) throws {
        if d.amount > 0 {
            let rest = balance(of: d.goalID, in: allDeposits(), excluding: d.id)
            if rest < -0.001 { throw DepositError.exceedsBalance(balance(of: d.goalID, in: allDeposits())) }
        }
        d.deletedAt = Date()
        d.updatedAt = Date()
        d.needsSync = true
        changed()
        Sound.shared.remove()
    }

    // MARK: zapis + widżety + synchronizacja

    private func save() { try? context.save() }

    private func changed() {
        save()
        objectWillChange.send()
        refreshWidget()
        syncSoon()
    }

    func refreshWidget() {
        guard let g = defaultGoal() else {
            SharedStore.save(WidgetSnapshot(goalName: "", saved: 0, target: 0, forecast: "", lang: L.lang, photoX: 50, photoY: 50, hasPhoto: false, updated: Date()), photo: nil)
            WidgetCenter.shared.reloadAllTimelines()
            return
        }
        let s = GoalStats(target: g.targetAmount, deposits: deposits(for: g.id))
        let pos = PhotoPosition(string: g.photoPosition)
        let small = g.photoData.flatMap { Self.downscale($0, max: 700) }
        let snap = WidgetSnapshot(goalName: g.name, saved: s.saved, target: s.target, forecast: s.forecastSentence(lang: L.lang),
                                  lang: L.lang, photoX: pos.x, photoY: pos.y, hasPhoto: small != nil, updated: Date())
        SharedStore.save(snap, photo: small)
        WidgetCenter.shared.reloadAllTimelines()
    }

    func syncSoon() {
        guard mode == .remote else { return }
        syncTask?.cancel()
        syncTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 600_000_000)
            guard !Task.isCancelled else { return }
            await self?.syncNow()
        }
    }

    /// Wysyła lokalne zmiany, pobiera zmiany z serwera (np. ze strony) oraz katalog i konfigurację.
    func syncNow() async {
        await loadPublic()
        guard mode == .remote, let uid = api.userID else { return }
        if syncing { pendingResync = true; return }
        syncing = true
        defer {
            syncing = false
            if pendingResync { pendingResync = false; syncSoon() }
        }
        do {
            try await pushPhotos(uid: uid)
            try await pushGoals()
            try await pushDeposits()
            try await pull()
            if let p: [RemoteProfileRow] = try? await api.get("/rest/v1/profiles?select=display_name,onboarded&id=eq.\(uid)", as: [RemoteProfileRow].self),
               let first = p.first {
                if !first.display_name.isEmpty { displayName = first.display_name; defaults.set(first.display_name, forKey: "displayName") }
                if first.onboarded && !onboarded { onboarded = true; defaults.set(true, forKey: "onboarded") }
            }
            syncError = nil
            lastSync = Date()
            defaults.set(lastSync, forKey: "lastSync")
            save()
            objectWillChange.send()
            refreshWidget()
        } catch {
            if case let APIError.http(code, _) = error, code == 401 {
                syncError = error.localizedDescription
            } else if (error as? URLError) != nil {
                syncError = L.t("offline")
            } else {
                syncError = error.localizedDescription
            }
        }
    }

    func loadPublic() async {
        guard api.isConfigured else { return }
        if let rows = try? await api.get("/rest/v1/macbook_catalog?select=*&is_active=eq.true&order=popularity.desc", as: [RemoteCatalogRow].self), !rows.isEmpty {
            catalog = rows
        }
        struct ConfigRow: Decodable {
            struct Value: Decodable { let latest_build: Int? }
            let value: Value
        }
        if let rows = try? await api.get("/rest/v1/app_config?select=value&key=eq.ios_update", as: [ConfigRow].self),
           let b = rows.first?.value.latest_build {
            latestBuild = b
        }
    }

    private func pushPhotos(uid: String) async throws {
        for g in allGoals() where g.photoNeedsUpload {
            guard let data = g.photoData, g.deletedAt == nil else { g.photoNeedsUpload = false; continue }
            let path = "\(uid)/\(g.id.uuidString.lowercased()).jpg"
            try await api.uploadPhoto(path: path, jpeg: data)
            g.photoURL = path
            g.photoNeedsUpload = false
            g.needsSync = true
        }
    }

    private func pushGoals() async throws {
        let dirty = allGoals().filter { $0.needsSync }
        guard !dirty.isEmpty else { return }
        // najpierw cele bez gwiazdki — w bazie może być tylko jeden główny
        let rows = dirty.sorted { !$0.isDefault && $1.isDefault }.map {
            RemoteGoalRow(id: $0.id, name: $0.name, target_amount: $0.targetAmount, photo_url: $0.photoURL, photo_position: $0.photoPosition,
                          catalog_id: $0.catalogID, is_default: $0.isDefault, created_at: ServerDate.string($0.createdAt),
                          updated_at: nil, deleted_at: ServerDate.string($0.deletedAt))
        }
        try await api.upsert("goals", rows: rows)
        for g in dirty { g.needsSync = false }
    }

    private func pushDeposits() async throws {
        let dirty = allDeposits().filter { $0.needsSync }
        guard !dirty.isEmpty else { return }
        let rows = dirty.sorted { $0.amount > $1.amount }.map {
            RemoteDepositRow(id: $0.id, goal_id: $0.goalID, amount: $0.amount, deposit_date: $0.day, note: $0.note,
                             created_at: ServerDate.string($0.createdAt), updated_at: nil, deleted_at: ServerDate.string($0.deletedAt))
        }
        try await api.upsert("deposits", rows: rows)
        for d in dirty { d.needsSync = false }
    }

    private func pull() async throws {
        let since = defaults.string(forKey: "lastPull")
        let filter = since.map { "&updated_at=gt.\($0.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? $0)" } ?? ""
        let goalRows = try await api.get("/rest/v1/goals?select=*\(filter)&order=updated_at", as: [RemoteGoalRow].self)
        let depRows = try await api.get("/rest/v1/deposits?select=*\(filter)&order=updated_at", as: [RemoteDepositRow].self)
        var newest = since

        let localGoals = Dictionary(allGoals().map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        for r in goalRows {
            let remoteUpdated = ServerDate.parse(r.updated_at) ?? Date.distantPast
            if let u = r.updated_at, u > (newest ?? "") { newest = u }
            let g: GoalEntity
            if let existing = localGoals[r.id] {
                if existing.needsSync && existing.updatedAt > remoteUpdated { continue }
                g = existing
            } else {
                g = GoalEntity(id: r.id, name: r.name, targetAmount: r.target_amount)
                g.createdAt = ServerDate.parse(r.created_at) ?? Date()
                context.insert(g)
            }
            let photoChanged = g.photoURL != r.photo_url
            g.name = r.name
            g.targetAmount = r.target_amount
            g.photoURL = r.photo_url
            g.photoPosition = r.photo_position
            g.catalogID = r.catalog_id
            g.isDefault = r.is_default
            g.deletedAt = ServerDate.parse(r.deleted_at)
            g.updatedAt = remoteUpdated
            g.needsSync = false
            if photoChanged || (g.photoData == nil && r.photo_url != nil) {
                g.photoData = await fetchPhoto(r.photo_url)
            }
        }

        let localDeps = Dictionary(allDeposits().map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        for r in depRows {
            let remoteUpdated = ServerDate.parse(r.updated_at) ?? Date.distantPast
            if let u = r.updated_at, u > (newest ?? "") { newest = u }
            if let d = localDeps[r.id] {
                if d.needsSync && d.updatedAt > remoteUpdated { continue }
                d.goalID = r.goal_id
                d.amount = r.amount
                d.day = r.deposit_date
                d.note = r.note
                d.deletedAt = ServerDate.parse(r.deleted_at)
                d.updatedAt = remoteUpdated
                d.needsSync = false
            } else {
                let d = DepositEntity(id: r.id, goalID: r.goal_id, amount: r.amount, day: r.deposit_date, note: r.note)
                d.createdAt = ServerDate.parse(r.created_at) ?? Date()
                d.updatedAt = remoteUpdated
                d.deletedAt = ServerDate.parse(r.deleted_at)
                d.needsSync = false
                context.insert(d)
            }
        }
        if let newest { defaults.set(newest, forKey: "lastPull") }
    }

    private func fetchPhoto(_ url: String?) async -> Data? {
        guard let url else { return nil }
        if url.hasPrefix("http") {
            guard let u = URL(string: url), let result = try? await URLSession.shared.data(from: u) else { return nil }
            let data = result.0
            guard UIImage(data: data) != nil else { return nil }
            return Self.jpeg(data)
        }
        return try? await api.downloadPhoto(path: url)
    }

    // MARK: eksport

    func exportJSON() -> URL? {
        let iso = ISO8601DateFormatter()
        let goalsOut: [[String: Any]] = goals().map {
            ["id": $0.id.uuidString.lowercased(), "name": $0.name, "target_amount": $0.targetAmount, "photo_url": $0.photoURL ?? NSNull(),
             "photo_position": $0.photoPosition, "catalog_id": $0.catalogID ?? NSNull(), "is_default": $0.isDefault,
             "created_at": iso.string(from: $0.createdAt)]
        }
        let depsOut: [[String: Any]] = allDeposits().filter { $0.deletedAt == nil }.map {
            ["id": $0.id.uuidString.lowercased(), "goal_id": $0.goalID.uuidString.lowercased(), "amount": $0.amount,
             "deposit_date": $0.day, "note": $0.note ?? NSNull()]
        }
        let payload: [String: Any] = ["app": "macbook progress", "exported_at": iso.string(from: Date()),
                                      "account": mode == .remote ? ["email": email] : NSNull(),
                                      "profile": ["display_name": displayName], "goals": goalsOut, "deposits": depsOut]
        guard let data = try? JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys]) else { return nil }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("macbook-progress-\(Day.today).json")
        try? data.write(to: url)
        return url
    }

    // MARK: zdjęcia

    static func jpeg(_ data: Data) -> Data {
        downscale(data, max: 1600) ?? data
    }

    static func downscale(_ data: Data, max side: CGFloat) -> Data? {
        guard let img = UIImage(data: data) else { return nil }
        let scale = min(1, side / Swift.max(img.size.width, img.size.height))
        let size = CGSize(width: (img.size.width * scale).rounded(), height: (img.size.height * scale).rounded())
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let out = UIGraphicsImageRenderer(size: size, format: format).image { _ in img.draw(in: CGRect(origin: .zero, size: size)) }
        return out.jpegData(compressionQuality: 0.85)
    }
}
