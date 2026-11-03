import Foundation
import Security

// Wiersze z bazy mają własne nazwy (Remote…Row), żeby nie myliły się z widokami.

struct RemoteGoalRow: Codable {
    var id: UUID
    var name: String
    var target_amount: Double
    var photo_url: String?
    var photo_position: String
    var catalog_id: String?
    var is_default: Bool
    var created_at: String?
    var updated_at: String?
    var deleted_at: String?

    /// zapis z jawnymi null (żeby usunięcie zdjęcia / przywrócenie trafiło do bazy)
    enum CodingKeys: String, CodingKey {
        case id, name, target_amount, photo_url, photo_position, catalog_id, is_default, created_at, updated_at, deleted_at
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id.uuidString.lowercased(), forKey: .id)
        try c.encode(name, forKey: .name)
        try c.encode(target_amount, forKey: .target_amount)
        try c.encode(photo_url, forKey: .photo_url)
        try c.encode(photo_position, forKey: .photo_position)
        try c.encode(catalog_id, forKey: .catalog_id)
        try c.encode(is_default, forKey: .is_default)
        if let created_at { try c.encode(created_at, forKey: .created_at) }
        try c.encode(deleted_at, forKey: .deleted_at)
    }
}

struct RemoteDepositRow: Codable {
    var id: UUID
    var goal_id: UUID
    var amount: Double
    var deposit_date: String
    var note: String?
    var created_at: String?
    var updated_at: String?
    var deleted_at: String?

    enum CodingKeys: String, CodingKey {
        case id, goal_id, amount, deposit_date, note, created_at, updated_at, deleted_at
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id.uuidString.lowercased(), forKey: .id)
        try c.encode(goal_id.uuidString.lowercased(), forKey: .goal_id)
        try c.encode(amount, forKey: .amount)
        try c.encode(deposit_date, forKey: .deposit_date)
        try c.encode(note, forKey: .note)
        if let created_at { try c.encode(created_at, forKey: .created_at) }
        try c.encode(deleted_at, forKey: .deleted_at)
    }
}

struct RemoteProfileRow: Codable {
    var display_name: String
    var onboarded: Bool
}

struct RemoteCatalogRow: Codable, Identifiable, Hashable {
    var id: String
    var family: String
    var name: String
    var chip: String
    var screen_inches: Double
    var cpu_cores: Int?
    var gpu_cores: Int?
    var memory_gb: Int
    var storage_gb: Int
    var price_pln: Double
    var popularity: Int
    var is_active: Bool

    var spec: String {
        let storage = storage_gb >= 1024 ? "\(storage_gb / 1024) TB" : "\(storage_gb) GB"
        let gpu = gpu_cores.map { " · \($0)-GPU" } ?? ""
        return "\(chip)\(gpu) · \(memory_gb) GB · \(storage)"
    }
}

struct RemoteSession: Codable {
    var access_token: String
    var refresh_token: String
    var expires_at: Double
    var user_id: String
    var email: String
}

enum APIError: LocalizedError {
    case notConfigured
    case http(Int, String)
    case confirmEmail

    var errorDescription: String? {
        switch self {
        case .notConfigured: return "Supabase not configured (Secrets.xcconfig)"
        case let .http(code, msg): return "\(code): \(msg)"
        case .confirmEmail: return "confirm_email"
        }
    }
}

/// Mały klient REST do Supabase (Auth, PostgREST, Storage) — bez dodatkowych bibliotek.
final class SupabaseAPI {
    static let shared = SupabaseAPI()

    let host: String
    let key: String
    private(set) var session: RemoteSession?

    var isConfigured: Bool { !host.isEmpty && !key.isEmpty }
    var userID: String? { session?.user_id }

    private init() {
        host = ((Bundle.main.object(forInfoDictionaryKey: "SupabaseHost") as? String) ?? "").trimmingCharacters(in: .whitespaces)
        key = ((Bundle.main.object(forInfoDictionaryKey: "SupabaseKey") as? String) ?? "").trimmingCharacters(in: .whitespaces)
        session = Keychain.loadSession()
    }

    private var base: URL { URL(string: "https://\(host)")! }

    // MARK: auth

    func signIn(email: String, password: String) async throws {
        let body = try JSONSerialization.data(withJSONObject: ["email": email, "password": password])
        let data = try await raw("POST", "/auth/v1/token?grant_type=password", body: body, auth: false)
        try storeSession(from: data)
    }

    func signUp(email: String, password: String, name: String) async throws {
        let payload: [String: Any] = ["email": email, "password": password, "data": ["display_name": name]]
        let data = try await raw("POST", "/auth/v1/signup", body: try JSONSerialization.data(withJSONObject: payload), auth: false)
        let obj = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        if obj?["access_token"] == nil { throw APIError.confirmEmail }
        try storeSession(from: data)
    }

    func signOut() {
        session = nil
        Keychain.saveSession(nil)
    }

    private func storeSession(from data: Data) throws {
        guard let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let access = obj["access_token"] as? String,
              let refresh = obj["refresh_token"] as? String,
              let user = obj["user"] as? [String: Any],
              let uid = user["id"] as? String
        else { throw APIError.http(0, "bad auth response") }
        let expiresIn = (obj["expires_in"] as? Double) ?? 3600
        let s = RemoteSession(access_token: access, refresh_token: refresh, expires_at: Date().timeIntervalSince1970 + expiresIn - 60,
                              user_id: uid, email: (user["email"] as? String) ?? "")
        session = s
        Keychain.saveSession(s)
    }

    private func refreshIfNeeded() async throws {
        guard let s = session, Date().timeIntervalSince1970 > s.expires_at else { return }
        let body = try JSONSerialization.data(withJSONObject: ["refresh_token": s.refresh_token])
        let data = try await raw("POST", "/auth/v1/token?grant_type=refresh_token", body: body, auth: false)
        try storeSession(from: data)
    }

    // MARK: REST

    func get<T: Decodable>(_ path: String, as type: T.Type) async throws -> T {
        let data = try await request("GET", path)
        return try JSONDecoder().decode(type, from: data)
    }

    func upsert<T: Encodable>(_ table: String, rows: [T]) async throws {
        guard !rows.isEmpty else { return }
        let body = try JSONEncoder().encode(rows)
        _ = try await request("POST", "/rest/v1/\(table)?on_conflict=id", body: body,
                              headers: ["Prefer": "resolution=merge-duplicates,return=minimal"])
    }

    func patch(_ path: String, json: [String: Any]) async throws {
        _ = try await request("PATCH", path, body: try JSONSerialization.data(withJSONObject: json), headers: ["Prefer": "return=minimal"])
    }

    func rpc(_ name: String, params: [String: Any] = [:]) async throws {
        _ = try await request("POST", "/rest/v1/rpc/\(name)", body: try JSONSerialization.data(withJSONObject: params))
    }

    // MARK: Storage (prywatny bucket goal-photos)

    func uploadPhoto(path: String, jpeg: Data) async throws {
        _ = try await request("POST", "/storage/v1/object/goal-photos/\(path)", body: jpeg,
                              headers: ["Content-Type": "image/jpeg", "x-upsert": "true"])
    }

    func downloadPhoto(path: String) async throws -> Data {
        try await request("GET", "/storage/v1/object/authenticated/goal-photos/\(path)")
    }

    func removePhotos(paths: [String]) async throws {
        guard !paths.isEmpty else { return }
        _ = try await request("DELETE", "/storage/v1/object/goal-photos", body: try JSONSerialization.data(withJSONObject: ["prefixes": paths]))
    }

    func listPhotos(prefix: String) async throws -> [String] {
        let body = try JSONSerialization.data(withJSONObject: ["prefix": prefix, "limit": 1000])
        let data = try await request("POST", "/storage/v1/object/list/goal-photos", body: body)
        let arr = (try? JSONSerialization.jsonObject(with: data)) as? [[String: Any]] ?? []
        return arr.compactMap { $0["name"] as? String }.map { "\(prefix)/\($0)" }
    }

    // MARK: niskopoziomowe

    private func request(_ method: String, _ path: String, body: Data? = nil, headers: [String: String] = [:]) async throws -> Data {
        try await refreshIfNeeded()
        return try await raw(method, path, body: body, headers: headers, auth: true)
    }

    private func raw(_ method: String, _ path: String, body: Data? = nil, headers: [String: String] = [:], auth: Bool) async throws -> Data {
        guard isConfigured, let url = URL(string: path, relativeTo: base) else { throw APIError.notConfigured }
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.timeoutInterval = 20
        req.setValue(key, forHTTPHeaderField: "apikey")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if auth, let token = session?.access_token {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        for (k, v) in headers { req.setValue(v, forHTTPHeaderField: k) }
        req.httpBody = body
        let (data, resp) = try await URLSession.shared.data(for: req)
        let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
        guard (200 ..< 300).contains(code) else {
            let obj = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
            let msg = (obj?["msg"] as? String) ?? (obj?["message"] as? String) ?? (obj?["error_description"] as? String)
                ?? String(data: data, encoding: .utf8) ?? ""
            throw APIError.http(code, msg)
        }
        return data
    }
}

/// Sesja logowania w pęku kluczy (Keychain), nie w UserDefaults.
enum Keychain {
    private static let account = "supabase-session"
    private static let service = "macbookprogress"

    static func saveSession(_ s: RemoteSession?) {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                    kSecAttrService as String: service,
                                    kSecAttrAccount as String: account]
        SecItemDelete(query as CFDictionary)
        guard let s, let data = try? JSONEncoder().encode(s) else { return }
        var add = query
        add[kSecValueData as String] = data
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        SecItemAdd(add as CFDictionary, nil)
    }

    static func loadSession() -> RemoteSession? {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                    kSecAttrService as String: service,
                                    kSecAttrAccount as String: account,
                                    kSecReturnData as String: true,
                                    kSecMatchLimit as String: kSecMatchLimitOne]
        var out: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &out) == errSecSuccess, let data = out as? Data else { return nil }
        return try? JSONDecoder().decode(RemoteSession.self, from: data)
    }
}

enum ServerDate {
    private static let withFraction: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private static let plain: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    static func parse(_ s: String?) -> Date? {
        guard var s else { return nil }
        // Postgres daje 6 cyfr po przecinku — skracamy do 3
        if let dot = s.firstIndex(of: ".") {
            var end = s.index(after: dot)
            while end < s.endIndex, s[end].isNumber { end = s.index(after: end) }
            let digits = s[s.index(after: dot) ..< end]
            if digits.count > 3 {
                s = String(s[..<s.index(dot, offsetBy: 4)]) + String(s[end...])
            }
        }
        if s.hasSuffix("+00:00") { s = String(s.dropLast(6)) + "Z" }
        return withFraction.date(from: s) ?? plain.date(from: s)
    }

    static func string(_ d: Date?) -> String? {
        guard let d else { return nil }
        return withFraction.string(from: d)
    }
}
