import AppIntents
import SwiftUI
import UIKit
import WidgetKit

// MARK: - Ustawienie „Pokaż zdjęcie” (Edytuj widżet)

struct ShowPhotoIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "macbook progress"
    static var description = IntentDescription("Postęp głównego celu.")

    @Parameter(title: "Pokaż zdjęcie", default: true)
    var showPhoto: Bool

    init() {}
}

// MARK: - Dane

struct ProgressEntry: TimelineEntry {
    let date: Date
    let snap: WidgetSnapshot
    let photo: UIImage?
    let showPhoto: Bool
    let isEmpty: Bool
}

private func currentEntry(showPhoto: Bool) -> ProgressEntry {
    if let s = SharedStore.load(), !s.goalName.isEmpty {
        return ProgressEntry(date: Date(), snap: s, photo: s.hasPhoto ? SharedStore.loadPhoto() : nil, showPhoto: showPhoto, isEmpty: false)
    }
    return ProgressEntry(date: Date(), snap: .placeholder, photo: nil, showPhoto: showPhoto, isEmpty: SharedStore.load() != nil)
}

struct HomeProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> ProgressEntry {
        ProgressEntry(date: Date(), snap: .placeholder, photo: nil, showPhoto: true, isEmpty: false)
    }

    func snapshot(for configuration: ShowPhotoIntent, in context: Context) async -> ProgressEntry {
        currentEntry(showPhoto: configuration.showPhoto)
    }

    func timeline(for configuration: ShowPhotoIntent, in context: Context) async -> Timeline<ProgressEntry> {
        // aplikacja odświeża widżety po każdej zmianie; dodatkowo co godzinę
        Timeline(entries: [currentEntry(showPhoto: configuration.showPhoto)], policy: .after(Date().addingTimeInterval(3600)))
    }
}

struct LockProvider: TimelineProvider {
    func placeholder(in context: Context) -> ProgressEntry {
        ProgressEntry(date: Date(), snap: .placeholder, photo: nil, showPhoto: false, isEmpty: false)
    }

    func getSnapshot(in context: Context, completion: @escaping (ProgressEntry) -> Void) {
        completion(currentEntry(showPhoto: false))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ProgressEntry>) -> Void) {
        completion(Timeline(entries: [currentEntry(showPhoto: false)], policy: .after(Date().addingTimeInterval(3600))))
    }
}

// MARK: - Wygląd

private enum WColor {
    static let surface = Color(UIColor { $0.userInterfaceStyle == .dark ? UIColor(white: 0.08, alpha: 1) : .white })
    static let muted = Color(UIColor { $0.userInterfaceStyle == .dark ? UIColor(white: 0.64, alpha: 1) : UIColor(white: 0.42, alpha: 1) })
    static let track = Color(UIColor { $0.userInterfaceStyle == .dark ? UIColor(white: 0.15, alpha: 1) : UIColor(white: 0.925, alpha: 1) })
    static let raised = Color(UIColor { $0.userInterfaceStyle == .dark ? UIColor(white: 0.11, alpha: 1) : UIColor(white: 0.953, alpha: 1) })
}

/// Zdjęcie z kadrem z aplikacji. `.desaturated` — na nieaktywnym pulpicie Maca i w trybie
/// przyciemnionym zdjęcie jest szare, a nie płaską plamą.
private struct WidgetPhoto: View {
    let image: UIImage
    let x: Double
    let y: Double

    var body: some View {
        GeometryReader { geo in
            let iw = max(image.size.width, 1)
            let ih = max(image.size.height, 1)
            let scale = max(geo.size.width / iw, geo.size.height / ih)
            let w = iw * scale
            let h = ih * scale
            Image(uiImage: image)
                .resizable()
                .widgetAccentedRenderingMode(.desaturated)
                .frame(width: w, height: h)
                .offset(x: (geo.size.width - w) * x / 100, y: (geo.size.height - h) * y / 100)
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

private struct Bar: View {
    let ratio: Double
    var height: CGFloat = 6
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(WColor.track)
                if ratio > 0 {
                    Capsule().fill(Color.dataBlue).frame(width: max(height, geo.size.width * ratio)).widgetAccentable()
                }
            }
        }
        .frame(height: height)
    }
}

private func percent(_ r: Double) -> String { "\(Int((r * 100).rounded(.down)))%" }

struct HomeWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: ProgressEntry

    private var s: WidgetSnapshot { entry.snap }
    private var photo: UIImage? { entry.showPhoto ? entry.photo : nil }

    var body: some View {
        Group {
            if entry.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Image("Laptop").renderingMode(.template).resizable().scaledToFit().frame(width: 28, height: 28)
                    Text(L.t("appName")).font(.system(size: 14, weight: .semibold))
                    Text(L.t("onbTitle")).font(.system(size: 12)).foregroundStyle(WColor.muted)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            } else if family == .systemMedium {
                medium
            } else {
                small
            }
        }
        .containerBackground(for: .widget) { WColor.surface }
    }

    private var small: some View {
        VStack(alignment: .leading, spacing: 5) {
            if let photo {
                WidgetPhoto(image: photo, x: s.photoX, y: s.photoY)
                    .frame(maxWidth: .infinity)
                    .frame(height: 62)
            } else {
                HStack {
                    Image("Laptop").renderingMode(.template).resizable().scaledToFit().frame(width: 24, height: 24).widgetAccentable()
                    Spacer()
                    Text(percent(s.ratio)).font(.system(size: 13, weight: .semibold).monospacedDigit()).foregroundStyle(WColor.muted)
                }
                Spacer(minLength: 0)
            }
            Text(s.goalName).font(.system(size: 13, weight: .semibold)).lineLimit(1)
            Text(Money.format(s.saved, lang: s.lang))
                .font(.system(size: photo == nil ? 22 : 17, weight: .bold).monospacedDigit())
                .lineLimit(1).minimumScaleFactor(0.6)
            Text("\(L.t("ofPrice", ["price": Money.format(s.target, lang: s.lang)]))")
                .font(.system(size: 11).monospacedDigit()).foregroundStyle(WColor.muted).lineLimit(1).minimumScaleFactor(0.7)
            Bar(ratio: s.ratio)
        }
    }

    private var medium: some View {
        HStack(spacing: 12) {
            if let photo {
                WidgetPhoto(image: photo, x: s.photoX, y: s.photoY)
                    .aspectRatio(4 / 3, contentMode: .fit)
            }
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    if photo == nil {
                        Image("Laptop").renderingMode(.template).resizable().scaledToFit().frame(width: 18, height: 18).widgetAccentable()
                    }
                    Text(s.goalName).font(.system(size: 14, weight: .semibold)).lineLimit(1)
                    Spacer(minLength: 0)
                    Text(percent(s.ratio)).font(.system(size: 13, weight: .semibold).monospacedDigit()).foregroundStyle(WColor.muted)
                }
                Text(Money.format(s.saved, lang: s.lang))
                    .font(.system(size: 24, weight: .bold).monospacedDigit()).lineLimit(1).minimumScaleFactor(0.6)
                Text("\(L.t("ofPrice", ["price": Money.format(s.target, lang: s.lang)])) · \(L.t("left").lowercased()) \(Money.format(s.left, lang: s.lang))")
                    .font(.system(size: 12).monospacedDigit()).foregroundStyle(WColor.muted).lineLimit(1).minimumScaleFactor(0.7)
                Bar(ratio: s.ratio)
                Spacer(minLength: 0)
                if !s.forecast.isEmpty {
                    Text(s.forecast).font(.system(size: 11)).foregroundStyle(WColor.muted).lineLimit(2)
                }
            }
        }
    }
}

struct LockWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: ProgressEntry
    private var s: WidgetSnapshot { entry.snap }

    var body: some View {
        Group {
            switch family {
            case .accessoryCircular:
                // jak widżet „Baterie”: ikona MacBooka w pierścieniu postępu
                Gauge(value: s.ratio) {
                    Image("Laptop").renderingMode(.template).resizable().scaledToFit().padding(2)
                }
                .gaugeStyle(.accessoryCircularCapacity)
                .widgetAccentable()
            case .accessoryRectangular:
                VStack(alignment: .leading, spacing: 2) {
                    Text(s.goalName).font(.system(size: 14, weight: .semibold)).lineLimit(1).widgetAccentable()
                    Text("\(Money.format(s.saved, lang: s.lang)) / \(Money.format(s.target, lang: s.lang))")
                        .font(.system(size: 13).monospacedDigit()).lineLimit(1).minimumScaleFactor(0.7)
                    ProgressView(value: s.ratio).progressViewStyle(.linear).widgetAccentable()
                }
            default:
                Text("\(s.goalName) · \(percent(s.ratio))")
            }
        }
        .containerBackground(for: .widget) { Color.clear }
    }
}

// MARK: - Widżety

struct HomeProgressWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "HomeProgress", intent: ShowPhotoIntent.self, provider: HomeProvider()) { entry in
            HomeWidgetView(entry: entry)
        }
        .configurationDisplayName("macbook progress")
        .description(L.t("widgetDesc"))
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct LockProgressWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "LockProgress", provider: LockProvider()) { entry in
            LockWidgetView(entry: entry)
        }
        .configurationDisplayName("macbook progress")
        .description(L.t("widgetDesc"))
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

@main
struct MacbookWidgetsBundle: WidgetBundle {
    var body: some Widget {
        HomeProgressWidget()
        LockProgressWidget()
    }
}
