import Foundation

struct MonthPoint: Identifiable {
    var id: String { key }
    let key: String // YYYY-MM
    let date: Date // 1. dzień miesiąca
    let inflow: Double
    let outflow: Double // ujemna
    let cumulative: Double
}

/// Te same wzory co na stronie (web/src/lib/stats.ts).
struct GoalStats {
    let saved: Double
    let target: Double
    let left: Double
    let ratio: Double
    let thisMonth: Double
    let pace: Double
    let avgDeposit: Double
    let depositCount: Int
    let withdrawalCount: Int
    let totalIn: Double
    let totalOut: Double
    let largest: Double
    let forecast: Date?
    let months: [MonthPoint]

    static let cal = Calendar(identifier: .gregorian)

    static func monthStart(_ d: Date) -> Date {
        cal.date(from: cal.dateComponents([.year, .month], from: d)) ?? d
    }

    static func addMonths(_ d: Date, _ n: Int) -> Date {
        cal.date(byAdding: .month, value: n, to: d) ?? d
    }

    init(target: Double, deposits all: [DepositEntity], now: Date = Date()) {
        let ds = all.filter { $0.deletedAt == nil }.sorted { $0.day == $1.day ? $0.createdAt < $1.createdAt : $0.day < $1.day }
        let r2: (Double) -> Double = { ($0 * 100).rounded() / 100 }
        self.target = target
        saved = r2(ds.reduce(0) { $0 + $1.amount })
        left = r2(max(0, target - saved))
        ratio = target > 0 ? min(1, max(0, saved / target)) : 0
        let ins = ds.filter { $0.amount > 0 }
        let outs = ds.filter { $0.amount < 0 }
        totalIn = r2(ins.reduce(0) { $0 + $1.amount })
        totalOut = r2(outs.reduce(0) { $0 + $1.amount })
        depositCount = ins.count
        withdrawalCount = outs.count
        avgDeposit = ins.isEmpty ? 0 : r2(totalIn / Double(ins.count))
        largest = ins.map(\.amount).max() ?? 0
        let curKey = String(Day.string(now).prefix(7))
        thisMonth = r2(ds.filter { $0.day.hasPrefix(curKey) }.reduce(0) { $0 + $1.amount })

        var points: [MonthPoint] = []
        if let first = ds.first, let last = ds.last {
            var m = GoalStats.monthStart(Day.date(first.day))
            let end = max(GoalStats.monthStart(now), GoalStats.monthStart(Day.date(last.day)))
            var cum = 0.0
            while m <= end {
                let key = String(Day.string(m).prefix(7))
                let inM = ds.filter { $0.day.hasPrefix(key) }
                let i = r2(inM.filter { $0.amount > 0 }.reduce(0) { $0 + $1.amount })
                let o = r2(inM.filter { $0.amount < 0 }.reduce(0) { $0 + $1.amount })
                cum = r2(cum + i + o)
                points.append(MonthPoint(key: key, date: m, inflow: i, outflow: o, cumulative: cum))
                m = GoalStats.addMonths(m, 1)
            }
        }
        months = points
        let span = max(1, points.filter { $0.date <= now }.count)
        pace = ds.isEmpty ? 0 : r2(saved / Double(span))
        if left == 0 && !ds.isEmpty {
            forecast = GoalStats.monthStart(now)
        } else if pace > 0 {
            forecast = GoalStats.addMonths(GoalStats.monthStart(now), Int((left / pace).rounded(.up)))
        } else {
            forecast = nil
        }
    }

    func forecastSentence(lang: String) -> String {
        if left == 0 && saved > 0 { return L.t("forecastDone") }
        guard let forecast, pace > 0 else { return L.t("forecastNone") }
        return L.t("forecast", ["month": L.monthYear(forecast), "pace": Money.format(pace.rounded(), lang: lang)])
    }
}

func balance(of goalID: UUID, in deposits: [DepositEntity], excluding: UUID? = nil) -> Double {
    let s = deposits.filter { $0.goalID == goalID && $0.deletedAt == nil && $0.id != excluding }.reduce(0) { $0 + $1.amount }
    return (s * 100).rounded() / 100
}
