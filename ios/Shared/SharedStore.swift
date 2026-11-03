import Foundation
import SwiftUI
import UIKit

/// Dane dla widżetów, zapisywane przez aplikację we wspólnym kontenerze App Group.
struct WidgetSnapshot: Codable, Equatable {
    var goalName: String
    var saved: Double
    var target: Double
    var forecast: String
    var lang: String
    var photoX: Double
    var photoY: Double
    var hasPhoto: Bool
    var updated: Date

    var ratio: Double { target > 0 ? min(1, max(0, saved / target)) : 0 }
    var left: Double { max(0, target - saved) }

    static let placeholder = WidgetSnapshot(
        goalName: "MacBook Air 13\" M5", saved: 3_650, target: 5_499,
        forecast: "", lang: "pl", photoX: 50, photoY: 50, hasPhoto: false, updated: Date()
    )
}

enum SharedStore {
    static var groupID: String {
        (Bundle.main.object(forInfoDictionaryKey: "AppGroup") as? String) ?? "group.macbookprogress"
    }

    static var containerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: groupID)
    }

    private static var snapshotURL: URL? { containerURL?.appendingPathComponent("widget.json") }
    static var photoURL: URL? { containerURL?.appendingPathComponent("widget-photo.jpg") }

    static func save(_ snap: WidgetSnapshot, photo: Data?) {
        guard let url = snapshotURL else { return }
        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .iso8601
        if let data = try? enc.encode(snap) { try? data.write(to: url, options: .atomic) }
        if let p = photoURL {
            if let photo { try? photo.write(to: p, options: .atomic) } else { try? FileManager.default.removeItem(at: p) }
        }
    }

    static func load() -> WidgetSnapshot? {
        guard let url = snapshotURL, let data = try? Data(contentsOf: url) else { return nil }
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        return try? dec.decode(WidgetSnapshot.self, from: data)
    }

    static func loadPhoto() -> UIImage? {
        guard let p = photoURL, let data = try? Data(contentsOf: p) else { return nil }
        return UIImage(data: data)
    }
}

/// „x% y%” — ten sam format co na stronie i w bazie (kolumna photo_position).
struct PhotoPosition: Equatable {
    var x: Double
    var y: Double

    init(x: Double = 50, y: Double = 50) {
        self.x = min(100, max(0, x))
        self.y = min(100, max(0, y))
    }

    init(string: String?) {
        let parts = (string ?? "").replacingOccurrences(of: "%", with: "").split(separator: " ")
        if parts.count == 2, let x = Double(parts[0]), let y = Double(parts[1]) {
            self.init(x: x, y: y)
        } else {
            self.init()
        }
    }

    var string: String { "\(Int(x.rounded()))% \(Int(y.rounded()))%" }
}

/// Zdjęcie wypełniające ramkę, z kadrem ustawionym przez PhotoPosition.
struct PositionedImage: View {
    let image: UIImage
    let position: PhotoPosition

    var body: some View {
        GeometryReader { geo in
            let iw = max(image.size.width, 1)
            let ih = max(image.size.height, 1)
            let scale = max(geo.size.width / iw, geo.size.height / ih)
            let w = iw * scale
            let h = ih * scale
            Image(uiImage: image)
                .resizable()
                .frame(width: w, height: h)
                .offset(x: (geo.size.width - w) * position.x / 100, y: (geo.size.height - h) * position.y / 100)
        }
        .clipped()
    }
}

enum Money {
    static func format(_ value: Double, lang: String, sign: Bool = false, decimals: Bool? = nil) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.locale = Locale(identifier: lang == "pl" ? "pl_PL" : "en_GB")
        f.groupingSeparator = "\u{00a0}"
        f.usesGroupingSeparator = true
        f.groupingSize = 3
        let hasFraction = (abs(value) * 100).rounded().truncatingRemainder(dividingBy: 100) != 0
        let showDec = decimals ?? hasFraction
        f.minimumFractionDigits = showDec ? 2 : 0
        f.maximumFractionDigits = showDec ? 2 : 0
        let body = f.string(from: NSNumber(value: abs(value))) ?? "\(abs(value))"
        let prefix = value < 0 ? "−" : (sign && value > 0 ? "+" : "")
        return "\(prefix)\(body)\u{00a0}zł"
    }

    static func compact(_ value: Double, lang: String) -> String {
        if abs(value) >= 1000 {
            let v = value / 1000
            let f = NumberFormatter()
            f.locale = Locale(identifier: lang == "pl" ? "pl_PL" : "en_GB")
            f.maximumFractionDigits = (abs(v) < 10 && v.truncatingRemainder(dividingBy: 1) != 0) ? 1 : 0
            let s = f.string(from: NSNumber(value: v)) ?? "\(v)"
            return lang == "pl" ? "\(s) tys." : "\(s)k"
        }
        return String(Int(value))
    }
}

/// Kolor danych (jedyny kolor w interfejsie) — ten sam co na stronie.
extension Color {
    static let dataBlue = Color(UIColor { t in
        t.userInterfaceStyle == .dark ? UIColor(red: 0x5b / 255, green: 0x93 / 255, blue: 0xe6 / 255, alpha: 1)
            : UIColor(red: 0x1d / 255, green: 0x5f / 255, blue: 0xbf / 255, alpha: 1)
    })
}

/// Daty dzienne jako "YYYY-MM-DD" (bez stref czasowych), jak kolumna deposit_date.
enum Day {
    static func string(_ date: Date) -> String {
        let c = Calendar(identifier: .gregorian).dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 2000, c.month ?? 1, c.day ?? 1)
    }

    static func date(_ s: String) -> Date {
        let p = s.prefix(10).split(separator: "-").compactMap { Int($0) }
        var c = DateComponents()
        c.year = p.count > 0 ? p[0] : 2000
        c.month = p.count > 1 ? p[1] : 1
        c.day = p.count > 2 ? p[2] : 1
        return Calendar(identifier: .gregorian).date(from: c) ?? Date()
    }

    static var today: String { string(Date()) }
}
