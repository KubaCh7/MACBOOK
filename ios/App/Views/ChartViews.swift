import Charts
import SwiftUI

private struct ChartPoint: Identifiable {
    let id: String
    let date: Date
    let value: Double
    let forecast: Bool
}

/// Uzbierane narastająco: linia w kolorze danych, przerywana prognoza, linia ceny.
/// Dotknięcie pokazuje wartość w wierszu nad wykresem (nie zasłania miesięcy).
struct CumulativeChart: View {
    let stats: GoalStats
    @State private var selected: Date?

    private var points: [ChartPoint] {
        var out: [ChartPoint] = []
        guard let first = stats.months.first else { return out }
        out.append(ChartPoint(id: "a0", date: GoalStats.addMonths(first.date, -1), value: 0, forecast: false))
        for m in stats.months { out.append(ChartPoint(id: "a\(m.key)", date: m.date, value: m.cumulative, forecast: false)) }
        return out
    }

    private var forecastPoints: [ChartPoint] {
        guard let last = points.last, stats.pace > 0, last.value < stats.target else { return [] }
        let need = Int(((stats.target - last.value) / stats.pace).rounded(.up))
        let shown = min(need, 36)
        let now = GoalStats.monthStart(Date())
        let start = last.date < now ? now : last.date
        var out = [ChartPoint(id: "f0", date: last.date, value: last.value, forecast: true)]
        for i in 1 ... max(1, shown) {
            out.append(ChartPoint(id: "f\(i)", date: GoalStats.addMonths(start, i), value: min(stats.target, last.value + stats.pace * Double(i)), forecast: true))
        }
        return out
    }

    private var all: [ChartPoint] { points + forecastPoints.dropFirst() }

    private var selectedPoint: ChartPoint? {
        guard let selected else { return nil }
        let key = L.monthYear(selected)
        return all.first { L.monthYear($0.date) == key }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // wiersz z wartością — zarezerwowany, więc nic nie skacze
            HStack(spacing: 8) {
                if let p = selectedPoint {
                    Text(L.monthYear(p.date)).foregroundStyle(Theme.muted)
                    Text(p.forecast ? L.t("forecastLegend") : L.t("saved")).foregroundStyle(Theme.muted)
                    Text(Money.format(p.value, lang: L.lang, decimals: p.forecast ? false : nil))
                        .fontWeight(.bold)
                        .foregroundStyle(p.forecast ? Theme.text : Color.dataBlue)
                } else {
                    legendLine(color: Color.dataBlue, dashed: false, text: L.t("saved"))
                    legendLine(color: Theme.muted, dashed: true, text: L.t("forecastLegend"))
                }
                Spacer(minLength: 0)
            }
            .font(.system(size: 12).monospacedDigit())
            .lineLimit(1)
            .frame(height: 18)

            if points.isEmpty {
                Text(L.t("noDeposits")).font(.system(size: 14)).foregroundStyle(Theme.muted)
                    .frame(maxWidth: .infinity, minHeight: 120, alignment: .center)
            } else {
                Chart {
                    RuleMark(y: .value("price", stats.target))
                        .foregroundStyle(Theme.text.opacity(0.5))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                        .annotation(position: .top, alignment: .trailing) {
                            Text("\(L.t("priceLine")) \(Money.format(stats.target, lang: L.lang))")
                                .font(.system(size: 11, weight: .semibold).monospacedDigit())
                                .foregroundStyle(Theme.text)
                        }
                    ForEach(points) { p in
                        LineMark(x: .value("m", p.date, unit: .month), y: .value("v", p.value), series: .value("s", "saved"))
                            .foregroundStyle(Color.dataBlue)
                            .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                    }
                    ForEach(forecastPoints) { p in
                        LineMark(x: .value("m", p.date, unit: .month), y: .value("v", p.value), series: .value("s", "forecast"))
                            .foregroundStyle(Theme.muted)
                            .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                    }
                    if let p = selectedPoint {
                        RuleMark(x: .value("m", p.date, unit: .month))
                            .foregroundStyle(Theme.muted.opacity(0.5))
                            .lineStyle(StrokeStyle(lineWidth: 1))
                        PointMark(x: .value("m", p.date, unit: .month), y: .value("v", p.value))
                            .foregroundStyle(p.forecast ? Theme.muted : Color.dataBlue)
                            .symbolSize(50)
                    }
                }
                .chartYScale(domain: 0 ... max(stats.target, points.map(\.value).max() ?? 0) * 1.12)
                .chartYAxis {
                    AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { v in
                        AxisGridLine().foregroundStyle(Theme.rule)
                        AxisValueLabel {
                            if let d = v.as(Double.self) { Text(Money.compact(d, lang: L.lang)).font(.system(size: 11)) }
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                        AxisValueLabel(format: .dateTime.month(.abbreviated), centered: false)
                    }
                }
                .chartXSelection(value: $selected)
                .environment(\.locale, L.locale)
                .frame(height: 200)
            }
        }
    }

    private func legendLine(color: Color, dashed: Bool, text: String) -> some View {
        HStack(spacing: 6) {
            Path { p in p.move(to: CGPoint(x: 0, y: 1)); p.addLine(to: CGPoint(x: 14, y: 1)) }
                .stroke(color, style: StrokeStyle(lineWidth: 2, dash: dashed ? [3, 3] : []))
                .frame(width: 14, height: 2)
            Text(text).foregroundStyle(Theme.muted)
        }
    }
}

/// Miesięcznie: wpłaty w górę (kolor danych), wypłaty w dół (czerwone).
struct MonthlyChart: View {
    let stats: GoalStats
    var count = 6
    @State private var selected: Date?

    private var series: [MonthPoint] {
        let byKey = Dictionary(stats.months.map { ($0.key, $0) }, uniquingKeysWith: { a, _ in a })
        let now = GoalStats.monthStart(Date())
        let end = max(now, stats.months.last?.date ?? now)
        return (0 ..< count).reversed().map { i in
            let d = GoalStats.addMonths(end, -i)
            let key = String(Day.string(d).prefix(7))
            return byKey[key] ?? MonthPoint(key: key, date: d, inflow: 0, outflow: 0, cumulative: 0)
        }
    }

    private var selectedPoint: MonthPoint? {
        guard let selected else { return nil }
        let key = String(Day.string(GoalStats.monthStart(selected)).prefix(7))
        return series.first { $0.key == key }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                if let p = selectedPoint {
                    Text(L.monthYear(p.date)).foregroundStyle(Theme.muted)
                    Text(Money.format(p.inflow, lang: L.lang, sign: p.inflow > 0)).fontWeight(.bold).foregroundStyle(Color.dataBlue)
                    if p.outflow < 0 {
                        Text(Money.format(p.outflow, lang: L.lang)).fontWeight(.bold).foregroundStyle(Theme.negative)
                    }
                } else {
                    swatch(Color.dataBlue, L.t("deposits"))
                    if series.contains(where: { $0.outflow < 0 }) { swatch(Theme.negative, L.t("withdrawals")) }
                }
                Spacer(minLength: 0)
            }
            .font(.system(size: 12).monospacedDigit())
            .lineLimit(1)
            .frame(height: 18)

            Chart {
                ForEach(series) { m in
                    BarMark(x: .value("m", m.date, unit: .month), y: .value("in", m.inflow), width: .ratio(0.55))
                        .foregroundStyle(Color.dataBlue)
                    if m.outflow < 0 {
                        BarMark(x: .value("m", m.date, unit: .month), y: .value("out", m.outflow), width: .ratio(0.55))
                            .foregroundStyle(Theme.negative)
                    }
                }
                RuleMark(y: .value("zero", 0)).foregroundStyle(Theme.border)
            }
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { v in
                    AxisGridLine().foregroundStyle(Theme.rule)
                    AxisValueLabel {
                        if let d = v.as(Double.self) { Text((d < 0 ? "−" : "") + Money.compact(abs(d), lang: L.lang)).font(.system(size: 11)) }
                    }
                }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .month)) { _ in
                    AxisValueLabel(format: .dateTime.month(.abbreviated), centered: true)
                }
            }
            .chartXSelection(value: $selected)
            .environment(\.locale, L.locale)
            .frame(height: 190)
        }
    }

    private func swatch(_ c: Color, _ text: String) -> some View {
        HStack(spacing: 6) {
            Rectangle().fill(c).frame(width: 8, height: 10)
            Text(text).foregroundStyle(Theme.muted)
        }
    }
}
