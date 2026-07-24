import SwiftUI

/// The Agenda: a full day-timeline (iOS-Calendar style) that overlays the user's
/// events with EMBER's recommended sleep, wake, and warming-bath blocks — plus a
/// science-based circadian energy ribbon (morning peak, afternoon dip, wind-down)
/// so the day can be planned around the body clock. Swipe left/right to change
/// day; the sleep and warming blocks drag to shift; each event opens a detail
/// sheet to reclassify or set a reminder.
struct AgendaView: View {
    @EnvironmentObject var store: DataStore
    @State private var selectedDay = Calendar.current.startOfDay(for: Date())
    @State private var showInfo = false

    private let cal = Calendar.current
    private var days: [Date] {
        (0..<14).compactMap { cal.date(byAdding: .day, value: $0, to: cal.startOfDay(for: Date())) }
    }

    var body: some View {
        ZStack {
            NightBackground()
            VStack(spacing: 0) {
                DayStrip(days: days, selectedDay: $selectedDay)
                    .padding(.top, 10)
                    .padding(.bottom, 12)
                TabView(selection: $selectedDay) {
                    ForEach(days, id: \.self) { day in
                        DayPage(day: day).tag(day)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.snappy, value: selectedDay)
            }
        }
        .navigationTitle("Agenda")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showInfo = true } label: { Image(systemName: "info.circle") }
            }
        }
        .sheet(isPresented: $showInfo) { AgendaInfoSheet().presentationDetents([.medium, .large]) }
    }
}

// MARK: - One day (banner + timeline), self-contained so paging is clean

private struct DayPage: View {
    let day: Date
    @EnvironmentObject var store: DataStore
    @EnvironmentObject var calendar: CalendarService
    @EnvironmentObject var wakeAlarm: WakeAlarmService

    @State private var plan: DayPlan?
    @State private var selectedEvent: AgendaEvent?
    @State private var selectedMarker: CircadianModel.Marker?

    private let cal = Calendar.current

    var body: some View {
        VStack(spacing: 0) {
            if let plan { PlanBanner(plan: plan) { rebuild() }.padding(.horizontal).padding(.bottom, 6) }
            ScrollViewReader { proxy in
                ScrollView {
                    DayCanvas(
                        day: day, events: eventsForWindow, plan: $plan,
                        wakeMin: minuteOfDay(store.user.targetWakeTime),
                        bedMin: minuteOfDay(store.user.targetBedTime),
                        onSelectEvent: { selectedEvent = $0 },
                        onSelectMarker: { selectedMarker = $0 },
                        onPlanChange: { store.updateTonightPlan($0) })
                    .padding(.horizontal, 12).padding(.bottom, 24)
                }
                .onAppear {
                    // Land on the part of the day that matters: now (today) or the
                    // evening wind-down, rather than the 6 AM top of the window.
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        withAnimation(.easeInOut) { proxy.scrollTo("focus", anchor: .center) }
                    }
                }
            }
        }
        .onAppear(perform: rebuild)
        .onChange(of: store.agendaEvents) { _ in rebuild() }
        .sheet(item: $selectedEvent) { event in
            EventDetailSheet(event: event)
                .environmentObject(store).environmentObject(calendar).environmentObject(wakeAlarm)
                .presentationDetents([.medium, .large])
        }
        .sheet(item: $selectedMarker) { marker in
            MarkerSheet(marker: marker).presentationDetents([.height(300)])
        }
    }

    private var eventsForWindow: [AgendaEvent] {
        let origin = cal.date(bySettingHour: 6, minute: 0, second: 0, of: cal.startOfDay(for: day))!
        let end = origin.addingTimeInterval(27 * 3600)
        return store.agendaEvents.filter { $0.end > origin && $0.start < end && !$0.isAllDay }
    }

    private func rebuild() {
        let offset = store.currentThermalRx?.prescribedOffsetMin ?? store.user.currentOffsetMin
        withAnimation(.snappy) {
            let rebuilt = DayPlanner.build(
                nightOf: day, user: store.user,
                warmingOffsetMin: offset, prepBufferMin: wakeAlarm.prepBufferMin,
                events: store.agendaEvents.filter { !$0.isAllDay })
            plan = rebuilt
            store.updateTonightPlan(rebuilt)
        }
    }
    private func minuteOfDay(_ s: String) -> Int {
        let p = s.split(separator: ":").compactMap { Int($0) }; return p.count >= 2 ? p[0]*60+p[1] : 0
    }
}

// MARK: - Day strip

private struct DayStrip: View {
    let days: [Date]
    @Binding var selectedDay: Date
    private let cal = Calendar.current
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(days, id: \.self) { day in
                        let sel = cal.isDate(day, inSameDayAs: selectedDay)
                        Button {
                            Haptics.tick()
                            withAnimation(.snappy) { selectedDay = day }
                        } label: {
                            VStack(spacing: 2) {
                                Text(day, format: .dateTime.weekday(.abbreviated)).font(.caption2)
                                Text(day, format: .dateTime.day()).font(.headline.weight(.semibold))
                            }
                            .frame(width: 46, height: 54)
                            .background(sel ? Theme.ember : Color.white.opacity(0.06),
                                        in: RoundedRectangle(cornerRadius: 14))
                            .foregroundStyle(sel ? .white : .primary)
                        }.buttonStyle(.plain).id(day)
                    }
                }.padding(.horizontal, 12)
            }
            .onChange(of: selectedDay) { day in
                withAnimation(.snappy) { proxy.scrollTo(day, anchor: .center) }
            }
        }
    }
}

// MARK: - Plan banner

private struct PlanBanner: View {
    let plan: DayPlan
    let onReset: () -> Void
    private var color: Color {
        switch plan.level { case .low: return Theme.mint; case .moderate: return Theme.amber; case .high: return Theme.ember }
    }
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // The box mascot "wakes up" (blue) for a good night and dims when the
            // night is squeezed — an at-a-glance, on-brand read of risk.
            BlueBoxMascot(isActive: plan.level != .high, isCurrentUser: false)
                .scaleEffect(0.6).frame(width: 46, height: 52)
                .animation(.spring(response: 0.5, dampingFraction: 0.6), value: plan.level)
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(plan.headline).font(.subheadline.weight(.semibold))
                    Spacer()
                    Tag(text: plan.level.label, color: color)
                }
                Text(plan.detail).font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 10) {
                    PlanMetric(systemImage: "bed.double.fill", value: clock(plan.bed))
                    PlanMetric(systemImage: "sunrise.fill", value: clock(plan.wake))
                    PlanMetric(systemImage: "moon.zzz.fill", value: fmtDur(plan.sleepDurationMin))
                    Spacer(minLength: 4)
                    Button(action: onReset) {
                        Image(systemName: "arrow.counterclockwise")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .frame(width: 36, height: 32)
                    .accessibilityLabel("Reset plan")
                }
            }
        }
        .emberCard(12)
    }
    private func clock(_ d: Date) -> String { d.formatted(.dateTime.hour().minute()) }
}

private struct PlanMetric: View {
    let systemImage: String
    let value: String

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: systemImage)
                .frame(width: 15)
            Text(value)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
        .font(.caption2.weight(.semibold))
        .foregroundStyle(.secondary)
        .frame(width: 64, height: 28, alignment: .leading)
    }
}

// MARK: - The timeline canvas

private struct DayCanvas: View {
    let day: Date
    let events: [AgendaEvent]
    @Binding var plan: DayPlan?
    let wakeMin: Int
    let bedMin: Int
    let onSelectEvent: (AgendaEvent) -> Void
    let onSelectMarker: (CircadianModel.Marker) -> Void
    let onPlanChange: (DayPlan) -> Void

    @State private var sleepBase: DayPlan?
    @State private var warmBase: DayPlan?
    @State private var lastStep = 0
    @State private var appeared = false     // spring-in for the plan bands
    @State private var pulse = false        // "you are here" energy orb

    private let cal = Calendar.current
    private let hourHeight: CGFloat = 58
    private let gutter: CGFloat = 44
    private let ribbonWidth: CGFloat = 44     // reserved right column for the energy ribbon + markers
    private let laneGap: CGFloat = 6
    private let startHour = 6
    private let spanHours = 27

    private var origin: Date { cal.date(bySettingHour: startHour, minute: 0, second: 0, of: cal.startOfDay(for: day))! }
    private var ppm: CGFloat { hourHeight / 60 }
    private var totalHeight: CGFloat { CGFloat(spanHours) * hourHeight }
    private func y(_ date: Date) -> CGFloat { CGFloat(date.timeIntervalSince(origin) / 60) * ppm }

    var body: some View {
        GeometryReader { geo in
            let laneX = gutter
            let ribbonX = geo.size.width - ribbonWidth
            let laneW = max(40, ribbonX - laneX - laneGap)

            ZStack(alignment: .topLeading) {
                hourGrid(width: geo.size.width)
                midnightDivider(width: geo.size.width)
                energyFill(ribbonX: ribbonX)          // non-interactive background
                if plan != nil {
                    warmingBand(laneX: laneX, laneW: laneW)
                    sleepBand(laneX: laneX, laneW: laneW)
                }
                eventBlocks(laneX: laneX, laneW: laneW)
                nowLine(ribbonX: ribbonX)
                energyMarkers(ribbonX: ribbonX)        // topmost → always tappable
                nowEnergyOrb(ribbonX: ribbonX)
                focusAnchor
            }
            .frame(width: geo.size.width, height: totalHeight)
        }
        .frame(height: totalHeight)
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.15)) { appeared = true }
            withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) { pulse = true }
        }
    }

    /// A glowing dot on the energy ribbon at the current time — "you are here",
    /// at your current predicted energy. Today only.
    @ViewBuilder private func nowEnergyOrb(ribbonX: CGFloat) -> some View {
        if cal.isDateInToday(day) {
            let yy = y(Date())
            if yy >= 0 && yy <= totalHeight {
                let a = CircadianModel.alertness(atMinute: minuteOf(Date()), wakeMin: wakeMin, bedMin: bedMin)
                let x = ribbonX + ribbonWidth * (1 - CGFloat(a))
                ZStack {
                    Circle().fill(Theme.amber.opacity(0.5)).frame(width: 22, height: 22)
                        .scaleEffect(pulse ? 1.5 : 1).opacity(pulse ? 0 : 0.6)
                    Circle().fill(Theme.amber).frame(width: 11, height: 11)
                        .overlay(Circle().strokeBorder(.white.opacity(0.9), lineWidth: 1.5))
                        .shadow(color: Theme.amber.opacity(0.8), radius: 6)
                }
                .offset(x: x - 11, y: yy - 11)
                .allowsHitTesting(false)
            }
        }
    }

    // Where to auto-scroll: current time today, else the evening warm-up.
    private var focusAnchor: some View {
        let target: Date = cal.isDateInToday(day) ? Date() : (plan?.warmingStart ?? origin.addingTimeInterval(15*3600))
        return Color.clear.frame(width: 1, height: 1).id("focus").offset(y: y(target))
    }

    private func hourGrid(width: CGFloat) -> some View {
        ForEach(0...spanHours, id: \.self) { h in
            let date = origin.addingTimeInterval(Double(h) * 3600)
            let yy = CGFloat(h) * hourHeight
            ZStack(alignment: .topLeading) {
                Rectangle().fill(Color.white.opacity(0.06)).frame(width: width, height: 0.5).offset(y: yy)
                Text(date, format: .dateTime.hour())
                    .font(.caption2).foregroundStyle(.secondary)
                    .frame(width: gutter - 8, alignment: .trailing)
                    .offset(x: 0, y: yy - 6)
            }
        }
    }

    // A labeled divider at midnight so "tomorrow" is unmistakable.
    @ViewBuilder private func midnightDivider(width: CGFloat) -> some View {
        let midnight = cal.startOfDay(for: cal.date(byAdding: .day, value: 1, to: day)!)
        let yy = y(midnight)
        if yy > 0 && yy < totalHeight {
            ZStack(alignment: .leading) {
                Rectangle().fill(Theme.ember.opacity(0.35)).frame(width: width, height: 1)
                Text(midnight, format: .dateTime.weekday(.abbreviated).month().day())
                    .font(.caption2.weight(.bold)).foregroundStyle(Theme.ember)
                    .padding(.horizontal, 8).padding(.vertical, 2)
                    .background(Theme.bg, in: Capsule())
                    .overlay(Capsule().strokeBorder(Theme.ember.opacity(0.4), lineWidth: 0.5))
                    .offset(x: gutter + 4)
            }
            .offset(y: yy)
        }
    }

    // MARK: energy ribbon (fill = non-interactive; markers = top layer)

    private func energyPoints(ribbonX: CGFloat) -> [CGPoint] {
        stride(from: 0, through: spanHours * 60, by: 12).map { m in
            let date = origin.addingTimeInterval(Double(m) * 60)
            let a = CircadianModel.alertness(atMinute: minuteOf(date), wakeMin: wakeMin, bedMin: bedMin)
            return CGPoint(x: ribbonX + ribbonWidth * (1 - CGFloat(a)), y: CGFloat(m) * ppm)
        }
    }

    private func energyFill(ribbonX: CGFloat) -> some View {
        let pts = energyPoints(ribbonX: ribbonX)
        return ZStack(alignment: .topLeading) {
            Path { p in
                p.move(to: CGPoint(x: ribbonX + ribbonWidth, y: 0))
                p.addLine(to: CGPoint(x: ribbonX + ribbonWidth, y: totalHeight))
                for pt in pts.reversed() { p.addLine(to: pt) }
                p.closeSubpath()
            }
            .fill(LinearGradient(colors: [Theme.amber.opacity(0.30), Theme.ember.opacity(0.10)],
                                 startPoint: .top, endPoint: .bottom))
            // Soft glow behind the curve for a luminous "energy" feel.
            Path { p in
                guard let f = pts.first else { return }
                p.move(to: f); for pt in pts.dropFirst() { p.addLine(to: pt) }
            }
            .stroke(Theme.amber.opacity(0.5), lineWidth: 5).blur(radius: 6)
            Path { p in
                guard let f = pts.first else { return }
                p.move(to: f); for pt in pts.dropFirst() { p.addLine(to: pt) }
            }
            .stroke(Theme.amber.opacity(0.85), lineWidth: 1.5)
            Text("ENERGY").font(.system(size: 8, weight: .bold)).foregroundStyle(.secondary)
                .rotationEffect(.degrees(90)).fixedSize()
                .offset(x: ribbonX + ribbonWidth - 8, y: 16)
        }
        .allowsHitTesting(false)
    }

    private func energyMarkers(ribbonX: CGFloat) -> some View {
        ForEach(markerInstances, id: \.key) { inst in
            Button { Haptics.tick(); onSelectMarker(inst.marker) } label: {
                Image(systemName: inst.marker.symbol)
                    .font(.system(size: 12, weight: .bold)).foregroundStyle(.white)
                    .frame(width: 26, height: 26)
                    .background(color(for: inst.marker.kind), in: Circle())
                    .overlay(Circle().strokeBorder(Theme.bg, lineWidth: 1.5))
                    .contentShape(Rectangle().inset(by: -9))   // ~44pt tap target
            }
            .buttonStyle(.plain)
            .offset(x: ribbonX + ribbonWidth / 2 - 13, y: y(inst.date) - 13)
        }
    }

    private var markerInstances: [(key: String, date: Date, marker: CircadianModel.Marker)] {
        let markers = CircadianModel.markers(wakeMin: wakeMin, bedMin: bedMin)
        var out: [(String, Date, CircadianModel.Marker)] = []
        for dayOffset in 0...1 {
            let base = cal.date(byAdding: .day, value: dayOffset, to: cal.startOfDay(for: day))!
            for m in markers {
                let date = base.addingTimeInterval(Double(m.minuteOfDay) * 60)
                if date >= origin && date <= origin.addingTimeInterval(Double(spanHours) * 3600) {
                    out.append(("\(dayOffset)-\(m.label)", date, m))
                }
            }
        }
        return out.map { (key: $0.0, date: $0.1, marker: $0.2) }
    }

    private func color(for kind: CircadianModel.MarkerKind) -> Color {
        switch kind {
        case .peak: return Theme.amber
        case .dip: return Theme.cool
        case .windDown: return Theme.ember
        case .deepSleep: return Theme.emberDeep
        case .caffeine: return .brown
        }
    }

    // MARK: plan bands

    @ViewBuilder private func sleepBand(laneX: CGFloat, laneW: CGFloat) -> some View {
        if let plan {
            let top = y(plan.bed), h = max(30, y(plan.wake) - y(plan.bed))
            band(color: Theme.ember, icon: "moon.stars.fill",
                 title: "Sleep · \(fmtDur(plan.sleepDurationMin))",
                 subtitle: "\(clock(plan.bed))–\(clock(plan.wake))",
                 width: laneW, height: h, lifted: sleepBase != nil)
                .offset(x: laneX, y: top)
                .simultaneousGesture(bandDrag(base: $sleepBase))
        }
    }

    @ViewBuilder private func warmingBand(laneX: CGFloat, laneW: CGFloat) -> some View {
        if let plan {
            let top = y(plan.warmingStart), h = max(30, y(plan.warmingEnd) - y(plan.warmingStart))
            band(color: Theme.amber, icon: "thermometer.sun.fill",
                 title: "Warm-up", subtitle: clock(plan.warmingStart),
                 width: laneW, height: h, lifted: warmBase != nil)
                .offset(x: laneX, y: top)
                .simultaneousGesture(bandDrag(base: $warmBase))
        }
    }

    private func band(color: Color, icon: String, title: String, subtitle: String,
                      width: CGFloat, height: CGFloat, lifted: Bool) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon).font(.caption)
            VStack(alignment: .leading, spacing: 0) {
                Text(title).font(.caption.weight(.bold))
                if height > 42 { Text(subtitle).font(.caption2).opacity(0.85) }
            }
            Spacer()
            Image(systemName: lifted ? "hand.draw.fill" : "arrow.up.and.down").font(.caption2).opacity(0.7)
        }
        .padding(.horizontal, 10)
        .frame(width: width, height: height, alignment: .topLeading).padding(.top, 4)
        .background(color.opacity(lifted ? 0.34 : 0.22), in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(color.opacity(lifted ? 0.9 : 0.55), lineWidth: lifted ? 1.5 : 1))
        .foregroundStyle(.white)
        .shadow(color: .black.opacity(lifted ? 0.4 : 0), radius: lifted ? 8 : 0, y: lifted ? 4 : 0)
        .scaleEffect(lifted ? 1.03 : (appeared ? 1 : 0.94), anchor: .leading)
        .opacity(appeared ? 1 : 0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: lifted)
    }

    /// Native-Calendar behavior: press-and-hold to pick up a block, then drag to
    /// move the WHOLE night (sleep + warm-up stay linked). A plain scroll never
    /// engages, so scrolling the timeline never shifts times. Snapped to 5 min.
    private func bandDrag(base: Binding<DayPlan?>) -> some Gesture {
        LongPressGesture(minimumDuration: 0.3)
            .sequenced(before: DragGesture(minimumDistance: 0))
            .onChanged { value in
                switch value {
                case .first(true):
                    break
                case .second(true, let drag):
                    if base.wrappedValue == nil { base.wrappedValue = plan; lastStep = 0; Haptics.light() }
                    guard let b = base.wrappedValue, let drag else { return }
                    let step = Int((drag.translation.height / ppm / 5).rounded()) * 5
                    var p = b
                    p.bed = shift(b.bed, step); p.wake = shift(b.wake, step)
                    p.warmingStart = shift(b.warmingStart, step); p.warmingEnd = shift(b.warmingEnd, step)
                    plan = p
                    onPlanChange(p)
                    if step != lastStep { Haptics.tick(); lastStep = step }
                default:
                    break
                }
            }
            .onEnded { _ in base.wrappedValue = nil }
    }

    // MARK: events (side-by-side column packing for overlaps)

    private func eventBlocks(laneX: CGFloat, laneW: CGFloat) -> some View {
        ForEach(positioned(events), id: \.event.id) { pos in
            let colW = (laneW - CGFloat(pos.cols - 1) * 4) / CGFloat(pos.cols)
            let x = laneX + CGFloat(pos.col) * (colW + 4)
            let top = max(0, y(pos.event.start))
            let h = max(26, y(pos.event.end) - y(pos.event.start))
            VStack(alignment: .leading, spacing: 1) {
                Text(pos.event.title).font(.caption.weight(.semibold)).lineLimit(pos.cols > 2 ? 1 : 2)
                if h > 34 && pos.cols < 3 {
                    Text("\(clock(pos.event.start))–\(clock(pos.event.end))").font(.caption2).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 7).padding(.vertical, 4)
            .frame(width: colW, height: h, alignment: .topLeading)
            .background(eventColor(pos.event).opacity(0.18), in: RoundedRectangle(cornerRadius: 9))
            .overlay(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2).fill(eventColor(pos.event)).frame(width: 3).padding(.vertical, 3)
            }
            .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(eventColor(pos.event).opacity(0.4), lineWidth: 1))
            .contentShape(Rectangle())
            .onTapGesture { Haptics.tick(); onSelectEvent(pos.event) }
            .offset(x: x, y: top)
        }
    }

    /// Greedy column assignment: transitively-overlapping events share a cluster
    /// and are split into side-by-side columns.
    private struct Positioned { let event: AgendaEvent; let col: Int; let cols: Int }
    private func positioned(_ events: [AgendaEvent]) -> [Positioned] {
        let sorted = events.sorted { $0.start < $1.start }
        var result: [Positioned] = []
        var cluster: [AgendaEvent] = []
        var clusterEnd: Date?

        func flush() {
            guard !cluster.isEmpty else { return }
            var colEnds: [Date] = []
            var colOf: [String: Int] = [:]
            for e in cluster {
                if let i = colEnds.firstIndex(where: { e.start >= $0 }) {
                    colEnds[i] = e.end; colOf[e.id] = i
                } else {
                    colEnds.append(e.end); colOf[e.id] = colEnds.count - 1
                }
            }
            let n = max(1, colEnds.count)
            for e in cluster { result.append(Positioned(event: e, col: colOf[e.id] ?? 0, cols: n)) }
            cluster = []; clusterEnd = nil
        }

        for e in sorted {
            if let ce = clusterEnd, e.start >= ce { flush() }
            cluster.append(e); clusterEnd = max(clusterEnd ?? e.end, e.end)
        }
        flush()
        return result
    }

    @ViewBuilder private func nowLine(ribbonX: CGFloat) -> some View {
        if cal.isDateInToday(day) {
            let yy = y(Date())
            if yy >= 0 && yy <= totalHeight {
                ZStack(alignment: .leading) {
                    Circle().fill(.red).frame(width: 7, height: 7)
                    Rectangle().fill(.red).frame(width: ribbonX - gutter + 3, height: 1.5).padding(.leading, 6)
                }
                .offset(x: gutter - 3, y: yy)
            }
        }
    }

    private func eventColor(_ e: AgendaEvent) -> Color {
        switch e.category {
        case "social_jetlag": return Theme.amber
        case "timezone_travel": return Theme.cool
        case "early_obligation": return Theme.ember
        case "demanding_event": return .pink
        default: return .gray
        }
    }
    private func clock(_ d: Date) -> String { d.formatted(.dateTime.hour().minute()) }
    private func minuteOf(_ d: Date) -> Int { let c = cal.dateComponents([.hour, .minute], from: d); return (c.hour ?? 0)*60 + (c.minute ?? 0) }
    private func shift(_ d: Date, _ minutes: Int) -> Date { d.addingTimeInterval(Double(minutes) * 60) }
}

// MARK: - Event detail sheet

private struct EventDetailSheet: View {
    let event: AgendaEvent
    @EnvironmentObject var store: DataStore
    @EnvironmentObject var calendar: CalendarService
    @EnvironmentObject var wakeAlarm: WakeAlarmService
    @Environment(\.dismiss) private var dismiss
    @State private var reminderSet = false

    private let types: [(String, String)] = [
        ("early_obligation", "Early start"),
        ("social_jetlag", "Late night"),
        ("timezone_travel", "Time-zone travel"),
        ("demanding_event", "Big day"),
        ("neutral", "No sleep impact"),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(event.title).font(.title3.weight(.bold))
                        Text("\(event.start.formatted(.dateTime.weekday().hour().minute())) – \(event.end.formatted(.dateTime.hour().minute()))")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                    if let why = event.why, !why.isEmpty {
                        Label { Text(why) } icon: { Image(systemName: "sparkles").foregroundStyle(Theme.ember) }
                            .font(.callout).emberCard(12)
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Text("How does this affect your sleep?").font(.subheadline.weight(.semibold))
                        ForEach(types, id: \.0) { key, label in
                            let active = current == key
                            Button {
                                Haptics.tick()
                                Task { await store.overrideEventCategory(eventId: event.id, category: key, calendar: calendar) }
                            } label: {
                                HStack {
                                    Text(label)
                                    Spacer()
                                    if active { Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.ember) }
                                }
                                .padding(.vertical, 10).padding(.horizontal, 12)
                                .background(active ? Theme.ember.opacity(0.14) : Color.white.opacity(0.05),
                                            in: RoundedRectangle(cornerRadius: 10))
                            }.buttonStyle(.plain)
                        }
                        Text("Your correction sticks and won't be re-analyzed.").font(.caption2).foregroundStyle(.secondary)
                    }
                    Button {
                        Task {
                            let start = event.start.addingTimeInterval(-90 * 60)
                            reminderSet = await wakeAlarm.addReminder(
                                at: start, title: "Wind down for \(event.title)",
                                body: "EMBER: start easing toward sleep so you're rested for \(event.title).")
                        }
                    } label: {
                        Label(reminderSet ? "Reminder set" : "Remind me to wind down",
                              systemImage: reminderSet ? "checkmark.circle.fill" : "bell.badge")
                            .frame(maxWidth: .infinity).padding(.vertical, 14)
                            .background(Theme.ember.opacity(reminderSet ? 0.2 : 1), in: RoundedRectangle(cornerRadius: 14))
                            .foregroundStyle(reminderSet ? Theme.mint : .white)
                    }.buttonStyle(.plain).disabled(reminderSet)
                }
                .padding()
            }
            .navigationTitle("Event").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }

    private var current: String { store.categoryOverride(for: event.id) ?? event.category }
}

// MARK: - Circadian marker sheet

private struct MarkerSheet: View {
    let marker: CircadianModel.Marker
    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: marker.symbol).font(.system(size: 40)).foregroundStyle(Theme.ember).padding(.top, 24)
            Text(marker.label).font(.title3.weight(.bold))
            Text(timeLabel).font(.subheadline).foregroundStyle(.secondary)
            Text(marker.detail).font(.callout).multilineTextAlignment(.center)
                .foregroundStyle(.secondary).padding(.horizontal, 24)
            Spacer()
        }
    }
    private var timeLabel: String { String(format: "%02d:%02d", marker.minuteOfDay / 60, marker.minuteOfDay % 60) }
}

// MARK: - Info / legend sheet

private struct AgendaInfoSheet: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    row("chart.line.uptrend.xyaxis", Theme.amber, "The energy ribbon",
                        "The wave on the right is your predicted circadian alertness through the day — anchored to your own sleep times. Wider (warmer) means higher energy.")
                    row("circle.grid.2x2.fill", Theme.cool, "Body-clock markers",
                        "Tap a dot on the ribbon for the science behind each moment: morning peak, afternoon dip, evening wake-maintenance zone, wind-down, and your last-coffee cutoff.")
                    row("moon.stars.fill", Theme.ember, "Your recommended night",
                        "The blue Sleep band and amber Warm-up band are EMBER's plan for the night. Drag either up or down to shift it — times snap to 5 minutes.")
                    row("calendar", .gray, "Your events",
                        "Tap any event to see how it affects your sleep, correct its type, or set a wind-down reminder.")
                    row("hand.draw", Theme.mint, "Getting around",
                        "Swipe left/right (or tap the date strip) to change day. Scroll to move through the hours.")
                }
                .padding()
            }
            .navigationTitle("Reading your day").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Got it") { dismiss() } } }
        }
    }
    private func row(_ icon: String, _ tint: Color, _ title: String, _ body: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon).foregroundStyle(tint).font(.title3).frame(width: 30)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(body).font(.footnote).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}


