import SwiftUI
import Charts

// MARK: - Generative UI for the Rest Coach
//
// The coach can embed native widgets in its replies by emitting fenced blocks:
//
//   :::ember
//   { "type": "sol_chart", "caption": "Your onset is trending down." }
//   :::
//
// Trend charts (sol/se/tib/offset) bind to the user's REAL store data — the
// model only chooses which to show — so graphs can never contain fabricated
// numbers. Generic "line"/"bar"/"stats" widgets carry model-supplied values,
// which the system prompt constrains to numbers already present in the context.

/// A decoded widget request from the LLM.
struct WidgetSpec: Decodable {
    let type: String
    var title: String?
    var caption: String?
    var yLabel: String?
    var items: [StatItem]?
    var steps: [String]?
    var points: [Point]?

    struct StatItem: Decodable { let label: String; let value: String; var caption: String? }
    struct Point: Decodable { let x: String; let y: Double }
}

/// A parsed piece of a coach message: either markdown text or a widget.
enum CoachSegment: Identifiable {
    case text(String)
    case widget(WidgetSpec)
    var id: String {
        switch self {
        case .text(let t): return "t:\(t.hashValue)"
        case .widget(let w): return "w:\(w.type):\(w.title ?? "")\(w.caption ?? "")"
        }
    }
}

enum CoachContent {
    private static let open = ":::ember"
    private static let close = ":::"

    /// Split raw coach content into ordered text / widget segments. Tolerant of a
    /// half-streamed trailing widget (it's simply omitted until its closing fence
    /// arrives), so parsing mid-stream never renders broken JSON.
    static func parse(_ raw: String) -> [CoachSegment] {
        var segments: [CoachSegment] = []
        var textBuf: [String] = []
        var widgetBuf: [String]? = nil

        func flushText() {
            let t = textBuf.joined(separator: "\n")
            if !t.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { segments.append(.text(t)) }
            textBuf = []
        }

        for line in raw.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if widgetBuf == nil {
                if trimmed == open { flushText(); widgetBuf = [] }
                else { textBuf.append(line) }
            } else if trimmed == close {
                let json = widgetBuf!.joined(separator: "\n")
                if let data = json.data(using: .utf8),
                   let spec = try? JSONDecoder().decode(WidgetSpec.self, from: data) {
                    segments.append(.widget(spec))
                }
                widgetBuf = nil
            } else {
                widgetBuf!.append(line)
            }
        }
        flushText()   // any unterminated widget block is intentionally dropped
        return segments
    }
}

// MARK: - Rendering

/// A coach message rendered as a stack of text bubbles + full-width widget cards.
struct CoachMessageView: View {
    let message: ChatMessage
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(CoachContent.parse(message.content)) { seg in
                switch seg {
                case .text(let t):
                    Text(.init(t))   // inline markdown
                        .font(.subheadline)
                        .padding(12)
                        .background(Theme.card, in: RoundedRectangle(cornerRadius: 16))
                        .frame(maxWidth: 300, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                case .widget(let spec):
                    CoachWidgetView(spec: spec)
                }
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct CoachWidgetView: View {
    let spec: WidgetSpec
    @EnvironmentObject var store: DataStore

    var body: some View {
        card {
            switch spec.type {
            case "sol_chart":    solChart
            case "se_chart":     seChart
            case "tib_chart":    tibChart
            case "offset_chart": offsetChart
            case "rhythm_chart": rhythmChart
            case "stats":        statsRow
            case "line", "bar":  genericChart(bar: spec.type == "bar")
            case "checklist":    checklist
            default:             EmptyView()   // "callout" etc. → title/caption only
            }
        }
    }

    // MARK: card chrome

    @ViewBuilder private func card<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if let title = spec.title, !title.isEmpty {
                Text(title).font(.subheadline.weight(.semibold))
            }
            content()
            if let caption = spec.caption, !caption.isEmpty {
                Text(caption).font(.footnote).foregroundStyle(Theme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .emberCard()
    }

    // MARK: store-bound charts (always accurate)

    private var solChart: some View {
        Chart {
            ForEach(store.sleepLogs) { log in
                if let sol = log.solMin {
                    LineMark(x: .value("Date", shortDate(log.date)), y: .value("SOL", sol))
                        .foregroundStyle(Theme.ember).interpolationMethod(.catmullRom)
                    PointMark(x: .value("Date", shortDate(log.date)), y: .value("SOL", sol))
                        .foregroundStyle(Theme.ember)
                }
            }
            RuleMark(y: .value("Target", 20))
                .foregroundStyle(Theme.mint.opacity(0.7))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 4]))
        }
        .frame(height: 180).chartYAxisLabel("SOL (min)")
        .chartXAxis { AxisMarks(values: .automatic(desiredCount: 4)) }
    }

    private var seChart: some View {
        Chart {
            ForEach(store.cbtiLogs) { log in
                if let se = log.sePct {
                    LineMark(x: .value("Date", shortDate(log.date)), y: .value("SE", se))
                        .foregroundStyle(Theme.cool).interpolationMethod(.catmullRom)
                }
            }
            RuleMark(y: .value("Increase", 90)).foregroundStyle(Theme.mint.opacity(0.7))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 4]))
            RuleMark(y: .value("Restrict", 85)).foregroundStyle(Theme.ember.opacity(0.6))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 4]))
        }
        .frame(height: 180).chartYScale(domain: 70...100).chartYAxisLabel("% efficiency")
        .chartXAxis { AxisMarks(values: .automatic(desiredCount: 4)) }
    }

    private var tibChart: some View {
        Chart(store.cbtiPrescriptions) { rx in
            BarMark(x: .value("Week", "W\(rx.week)"), y: .value("TIB", rx.tibMin))
                .foregroundStyle(Theme.cool)
        }
        .frame(height: 180).chartYAxisLabel("time in bed (min)")
    }

    private var offsetChart: some View {
        Chart(store.prescriptions) { rx in
            LineMark(x: .value("Block", "B\(rx.block)"), y: .value("Offset", rx.prescribedOffsetMin))
                .foregroundStyle(Theme.ember).interpolationMethod(.catmullRom)
            PointMark(x: .value("Block", "B\(rx.block)"), y: .value("Offset", rx.prescribedOffsetMin))
                .foregroundStyle(Theme.ember)
        }
        .frame(height: 180).chartYAxisLabel("warming offset (min)")
    }

    private var rhythmChart: some View {
        let points = Array(store.regularity.midpoints.enumerated()).map {
            RhythmWidgetPoint(index: $0.offset, point: $0.element)
        }
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                LegendDot(color: Theme.cool, label: "Weeknight")
                LegendDot(color: Theme.amber, label: "Weekend")
                Spacer()
                if let spread = store.regularity.midpointStdevMin {
                    Text("±\(Int(spread))m drift")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Theme.secondaryText)
                }
            }
            Chart {
                ForEach(points) { p in
                    PointMark(
                        x: .value("Night", p.index),
                        y: .value("Midpoint", p.hours)
                    )
                    .foregroundStyle(p.point.isWeekend ? Theme.amber : Theme.cool)
                    .symbolSize(p.point.isWeekend ? 70 : 48)
                }
                if let midpoint = store.regularity.avgMidpoint, let hour = hourValue(midpoint) {
                    RuleMark(y: .value("Typical", hour))
                        .foregroundStyle(Color.white.opacity(0.22))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                }
            }
            .frame(height: 190)
            .chartYAxisLabel("midpoint")
            .chartXAxis {
                AxisMarks(values: rhythmAxisValues(count: points.count)) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                        .foregroundStyle(Color.white.opacity(0.10))
                    AxisValueLabel {
                        if let index = value.as(Int.self), let point = points.first(where: { $0.index == index }) {
                            Text(rhythmAxisLabel(for: point, total: points.count))
                                .font(.caption2)
                                .foregroundStyle(Theme.secondaryText)
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks(values: .automatic(desiredCount: 4)) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                        .foregroundStyle(Color.white.opacity(0.10))
                    AxisValueLabel {
                        if let hour = value.as(Double.self) {
                            Text(clockHour(hour))
                                .font(.caption2)
                                .foregroundStyle(Theme.secondaryText)
                        }
                    }
                }
            }
        }
    }

    // MARK: model-supplied content

    private var statsRow: some View {
        HStack(spacing: 0) {
            ForEach(Array((spec.items ?? []).enumerated()), id: \.offset) { i, item in
                if i > 0 { Divider().frame(height: 40).overlay(Color.white.opacity(0.1)) }
                VStack(spacing: 2) {
                    Text(item.value).font(.system(.title2, design: .rounded).weight(.bold))
                        .foregroundStyle(i == 0 ? Theme.ember : .primary)
                    Text(item.label).font(.caption).foregroundStyle(Theme.secondaryText)
                    if let c = item.caption { Text(c).font(.caption2).foregroundStyle(Theme.secondaryText) }
                }.frame(maxWidth: .infinity)
            }
        }
    }

    private func genericChart(bar: Bool) -> some View {
        let points = spec.points ?? []
        return Chart(Array(points.enumerated()), id: \.offset) { _, p in
            if bar {
                BarMark(x: .value("x", p.x), y: .value(spec.yLabel ?? "value", p.y))
                    .foregroundStyle(Theme.ember)
            } else {
                LineMark(x: .value("x", p.x), y: .value(spec.yLabel ?? "value", p.y))
                    .foregroundStyle(Theme.ember).interpolationMethod(.catmullRom)
            }
        }
        .frame(height: 180)
        .chartYAxisLabel(spec.yLabel ?? "")
    }

    private var checklist: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array((spec.steps ?? []).enumerated()), id: \.offset) { _, step in
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "checkmark.circle").foregroundStyle(Theme.mint).font(.subheadline)
                    Text(step).font(.footnote).fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private func rhythmAxisValues(count: Int) -> [Int] {
        guard count > 1 else { return [0] }
        let step = count > 21 ? 7 : max(1, count / 4)
        var values = Array(stride(from: 0, to: count, by: step))
        if values.last != count - 1 { values.append(count - 1) }
        return values
    }

    private func rhythmAxisLabel(for point: RhythmWidgetPoint, total: Int) -> String {
        if point.index == total - 1 { return "last" }
        return shortDate(point.point.day)
    }

    private func hourValue(_ hhmm: String) -> Double? {
        let parts = hhmm.split(separator: ":").compactMap { Double($0) }
        guard parts.count >= 2 else { return nil }
        return parts[0] + parts[1] / 60
    }

    private func clockHour(_ hour: Double) -> String {
        let total = Int((hour * 60).rounded()) % 1440
        return String(format: "%02d:%02d", total / 60, total % 60)
    }
}

private struct RhythmWidgetPoint: Identifiable {
    let index: Int
    let point: SleepScience.RegularityReport.MidpointPoint
    var id: String { point.id }
    var hours: Double { Double(point.minOfDay) / 60 }
}

private struct LegendDot: View {
    let color: Color
    let label: String

    var body: some View {
        HStack(spacing: 5) {
            Circle().fill(color).frame(width: 7, height: 7)
            Text(label).font(.caption2.weight(.semibold)).foregroundStyle(Theme.secondaryText)
        }
    }
}
