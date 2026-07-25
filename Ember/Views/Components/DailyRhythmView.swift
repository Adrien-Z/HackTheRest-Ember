import SwiftUI

struct DailyRhythmView: View {
    @StateObject private var viewModel = DailyRhythmViewModel()

    let sunriseHour: Double
    let sunsetHour: Double
    let windDownHour: Double
    let sleepStartHour: Double
    let wakeHour: Double

    init(
        sunriseHour: Double = 7.03,
        sunsetHour: Double = 18.5,
        windDownHour: Double = 22,
        sleepStartHour: Double = 23,
        wakeHour: Double = 7
    ) {
        self.sunriseHour = sunriseHour
        self.sunsetHour = sunsetHour
        self.windDownHour = windDownHour
        self.sleepStartHour = sleepStartHour
        self.wakeHour = wakeHour
    }

    private var peakHour: Double {
        resolvedSunriseHour + max(0.1, resolvedSunsetHour - resolvedSunriseHour) / 2
    }

    private var resolvedSunriseHour: Double {
        guard let sunrise = viewModel.sunrise else {
            return sunriseHour
        }

        print("Input sunrise Date:")
        print(sunrise)
        let decimalHour = Self.decimalHour(from: sunrise)
        print("Sunrise decimal:")
        print(String(format: "%.2f", decimalHour))
        return decimalHour
    }

    private var resolvedSunsetHour: Double {
        guard let sunset = viewModel.sunset else {
            return sunsetHour
        }

        print("Input sunset Date:")
        print(sunset)
        let decimalHour = Self.decimalHour(from: sunset)
        print("Sunset decimal:")
        print(String(format: "%.2f", decimalHour))
        return decimalHour
    }

    var body: some View {
        GeometryReader { proxy in
            let geometry = RhythmGeometry(
                size: proxy.size,
                sunriseHour: resolvedSunriseHour,
                sunsetHour: resolvedSunsetHour)

            ZStack {
                Image("DailyRhythmBackground")
                    .resizable()
                    .scaledToFill()
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .clipped()
                    .opacity(0.42)

                RhythmCurveCanvas(geometry: geometry)

                RhythmEventOverlay(
                    geometry: geometry,
                    sunriseHour: resolvedSunriseHour,
                    peakHour: peakHour,
                    sunsetHour: resolvedSunsetHour,
                    windDownHour: windDownHour,
                    sleepStartHour: sleepStartHour,
                    wakeHour: wakeHour)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .frame(height: 292)
        .task {
            await viewModel.fetchSunSchedule()
        }
    }

    private static func decimalHour(from date: Date) -> Double {
        let components = londonCalendar.dateComponents([.hour, .minute, .second], from: date)
        let hour = Double(components.hour ?? 0)
        let minute = Double(components.minute ?? 0) / 60
        let second = Double(components.second ?? 0) / 3600
        return hour + minute + second
    }

    private static var londonCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/London") ?? TimeZone(secondsFromGMT: 0)!
        return calendar
    }
}

private struct RhythmGeometry {
    let size: CGSize
    let sunriseHour: Double
    let sunsetHour: Double

    var horizonY: CGFloat { size.height * 0.54 }
    var amplitude: CGFloat { size.height * 0.30 }
    var dayDuration: Double { max(0.1, sunsetHour - sunriseHour) }
    var nightDuration: Double { max(0.1, 24 - dayDuration) }

    func point(angle: Double) -> CGPoint {
        CGPoint(
            x: size.width * CGFloat(angle / (.pi * 2)),
            y: horizonY - amplitude * CGFloat(sin(angle)))
    }

    func point(clockHour: Double) -> CGPoint {
        point(angle: angle(clockHour: clockHour))
    }

    func y(clockHour: Double) -> CGFloat {
        horizonY - amplitude * CGFloat(sin(angle(clockHour: clockHour)))
    }

    func angle(clockHour: Double) -> Double {
        let cycleHour = clockHour >= sunriseHour ? clockHour - sunriseHour : clockHour + 24 - sunriseHour
        if cycleHour <= dayDuration {
            return cycleHour / dayDuration * .pi
        }

        return .pi + (cycleHour - dayDuration) / nightDuration * .pi
    }
}

private struct RhythmCurveCanvas: View {
    let geometry: RhythmGeometry

    var body: some View {
        Canvas { context, size in
            let dayPath = curvePath(from: 0, to: .pi)
            let nightPath = curvePath(from: .pi, to: .pi * 2)
            let horizon = horizonPath(width: size.width)

            context.stroke(
                horizon,
                with: .linearGradient(
                    Gradient(colors: [
                        Color.white.opacity(0.22),
                        Color(red: 1.0, green: 0.78, blue: 0.38).opacity(0.40),
                        Color(red: 0.52, green: 0.50, blue: 1.0).opacity(0.36),
                        Color.white.opacity(0.20)
                    ]),
                    startPoint: CGPoint(x: 0, y: geometry.horizonY),
                    endPoint: CGPoint(x: size.width, y: geometry.horizonY)),
                lineWidth: 0.9)

            strokeGlow(
                context: context,
                path: dayPath,
                colors: [
                    Color(red: 1.0, green: 0.82, blue: 0.38).opacity(0.22),
                    Color(red: 1.0, green: 0.54, blue: 0.28).opacity(0.16)
                ],
                start: geometry.point(angle: 0),
                end: geometry.point(angle: .pi))

            strokeGlow(
                context: context,
                path: nightPath,
                colors: [
                    Color(red: 0.76, green: 0.44, blue: 1.0).opacity(0.18),
                    Color(red: 0.30, green: 0.52, blue: 1.0).opacity(0.20)
                ],
                start: geometry.point(angle: .pi),
                end: geometry.point(angle: .pi * 2))

            context.stroke(
                dayPath,
                with: .linearGradient(
                    Gradient(colors: [
                        Color(red: 1.0, green: 0.86, blue: 0.46),
                        Color(red: 1.0, green: 0.55, blue: 0.30)
                    ]),
                    startPoint: geometry.point(angle: 0),
                    endPoint: geometry.point(angle: .pi)),
                style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round))

            context.stroke(
                nightPath,
                with: .linearGradient(
                    Gradient(colors: [
                        Color(red: 0.78, green: 0.48, blue: 1.0),
                        Color(red: 0.34, green: 0.56, blue: 1.0)
                    ]),
                    startPoint: geometry.point(angle: .pi),
                    endPoint: geometry.point(angle: .pi * 2)),
                style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round))
        }
    }

    private func strokeGlow(
        context: GraphicsContext,
        path: Path,
        colors: [Color],
        start: CGPoint,
        end: CGPoint
    ) {
        context.stroke(
            path,
            with: .linearGradient(Gradient(colors: colors), startPoint: start, endPoint: end),
            style: StrokeStyle(lineWidth: 8, lineCap: .round, lineJoin: .round))
    }

    private func curvePath(from start: Double, to end: Double) -> Path {
        var path = Path()
        let samples = 160
        for index in 0...samples {
            let progress = Double(index) / Double(samples)
            let angle = start + (end - start) * progress
            let point = geometry.point(angle: angle)
            index == 0 ? path.move(to: point) : path.addLine(to: point)
        }
        return path
    }

    private func horizonPath(width: CGFloat) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: geometry.horizonY))
        path.addLine(to: CGPoint(x: width, y: geometry.horizonY))
        return path
    }
}

private struct RhythmEventOverlay: View {
    let geometry: RhythmGeometry
    let sunriseHour: Double
    let peakHour: Double
    let sunsetHour: Double
    let windDownHour: Double
    let sleepStartHour: Double
    let wakeHour: Double

    private var scheduleEventsAreClose: Bool {
        abs(sleepStartHour - windDownHour) <= 1.5
    }

    var body: some View {
        ZStack {
            ForEach(positionedMarkers) { marker in
                RhythmPointMarker(
                    time: marker.time,
                    title: marker.title,
                    coordinate: marker.coordinate,
                    placement: marker.placement,
                    accentColor: marker.accentColor,
                    showGuideLine: marker.showGuideLine,
                    containerWidth: geometry.size.width,
                    containerHeight: geometry.size.height,
                    isCurrentState: marker.isCurrentState,
                    verticalAdjustment: marker.verticalAdjustment,
                    labelHorizontalAdjustment: marker.labelHorizontalAdjustment,
                    textAlignmentOverride: marker.textAlignmentOverride)
            }
        }
    }

    private var positionedMarkers: [RhythmMarkerSpec] {
        var resolved: [RhythmMarkerSpec] = []

        for marker in baseMarkers.sorted(by: { $0.coordinate.x < $1.coordinate.x }) {
            var candidate = marker
            candidate.verticalAdjustment += collisionAdjustment(for: candidate, against: resolved)
            resolved.append(candidate)
        }

        return resolved
    }

    private var baseMarkers: [RhythmMarkerSpec] {
        [
            RhythmMarkerSpec(
                id: "sunrise",
                time: rhythmTimeLabel(sunriseHour),
                title: "Sunrise",
                coordinate: geometry.point(clockHour: sunriseHour),
                placement: .axisBelow,
                accentColor: Color(red: 1.0, green: 0.82, blue: 0.38),
                showGuideLine: true),
            RhythmMarkerSpec(
                id: "sunset",
                time: rhythmTimeLabel(sunsetHour),
                title: "Sunset",
                coordinate: geometry.point(clockHour: sunsetHour),
                placement: .above,
                accentColor: Color(red: 1.0, green: 0.55, blue: 0.30),
                showGuideLine: true),
            RhythmMarkerSpec(
                id: "sleep",
                time: rhythmTimeLabel(sleepStartHour),
                title: "Sleep",
                coordinate: geometry.point(clockHour: sleepStartHour),
                placement: .below,
                accentColor: Color(red: 0.76, green: 0.72, blue: 1.0),
                showGuideLine: true,
                isCurrentState: true,
                verticalAdjustment: scheduleEventsAreClose ? 6 : 0),
            RhythmMarkerSpec(
                id: "wake",
                time: rhythmTimeLabel(wakeHour),
                title: "Wake",
                coordinate: geometry.point(clockHour: wakeHour),
                placement: .above,
                accentColor: Color(red: 1.0, green: 0.82, blue: 0.42),
                showGuideLine: true)
        ]
    }

    private func collisionAdjustment(for marker: RhythmMarkerSpec, against placedMarkers: [RhythmMarkerSpec]) -> CGFloat {
        let candidates: [CGFloat]
        switch marker.placement {
        case .above:
            candidates = [0, -18, 18, -36, 36, -54, 54]
        case .below, .axisBelow:
            candidates = [0, 18, -18, 36, -36, 54, -54]
        }

        for adjustment in candidates {
            let rect = labelRect(for: marker, verticalAdjustment: marker.verticalAdjustment + adjustment)
            let hasCollision = placedMarkers.contains {
                rect.intersects(labelRect(for: $0, verticalAdjustment: $0.verticalAdjustment))
            }
            if !hasCollision {
                return adjustment
            }
        }

        return candidates.last ?? 0
    }

    private func labelRect(for marker: RhythmMarkerSpec, verticalAdjustment: CGFloat) -> CGRect {
        let layout = MarkerLayout(
            markerPoint: marker.coordinate,
            labelAlignment: .center,
            verticalDirection: marker.placement.verticalDirection,
            isAxisLevel: marker.placement.isAxisLevel,
            usesGuideLine: marker.showGuideLine,
            verticalAdjustment: verticalAdjustment,
            labelHorizontalAdjustment: marker.labelHorizontalAdjustment,
            containerWidth: geometry.size.width,
            containerHeight: geometry.size.height)
        let position = layout.labelPosition
        return CGRect(
            x: position.x - MarkerLayout.labelWidth / 2,
            y: position.y - MarkerLayout.labelHeight / 2,
            width: MarkerLayout.labelWidth,
            height: MarkerLayout.labelHeight)
    }
}

private struct RhythmMarkerSpec: Identifiable {
    let id: String
    let time: String
    let title: String
    let coordinate: CGPoint
    let placement: RhythmPointMarker.Placement
    let accentColor: Color
    let showGuideLine: Bool
    var isCurrentState: Bool = false
    var verticalAdjustment: CGFloat = 0
    var labelHorizontalAdjustment: CGFloat = 0
    var textAlignmentOverride: TextAlignment?
}

private struct MarkerLayout {
    enum VerticalDirection {
        case above
        case below

        var multiplier: CGFloat {
            self == .above ? -1 : 1
        }
    }

    let markerPoint: CGPoint
    let labelAlignment: Alignment
    let verticalDirection: VerticalDirection
    let isAxisLevel: Bool
    var usesGuideLine: Bool
    var verticalAdjustment: CGFloat = 0
    var labelHorizontalAdjustment: CGFloat = 0
    let containerWidth: CGFloat
    let containerHeight: CGFloat
    
    static let labelWidth: CGFloat = 72
    static let labelHeight: CGFloat = 34

    private var guideLength: CGFloat {
        usesGuideLine ? 24 : 0
    }

    private var labelDistance: CGFloat {
        if usesGuideLine {
            return 34
        }

        return curveAwareLabelDistance
    }

    var guideEnd: CGPoint {
        CGPoint(
            x: markerPoint.x,
            y: markerPoint.y + verticalDirection.multiplier * guideLength)
    }
    
    private var horizontalOffset: CGFloat {
        let halfWidth = Self.labelWidth / 2
        let leftBound = halfWidth
        let rightBound = containerWidth - halfWidth
        let preferredX = markerPoint.x + curveAvoidanceOffset + labelHorizontalAdjustment
        
        if preferredX < leftBound {
            return leftBound - markerPoint.x
        } else if preferredX > rightBound {
            return rightBound - markerPoint.x
        } else {
            return curveAvoidanceOffset + labelHorizontalAdjustment
        }
    }

    var labelPosition: CGPoint {
        CGPoint(
            x: markerPoint.x + horizontalOffset,
            y: boundedY(markerPoint.y + verticalDirection.multiplier * labelDistance + verticalAdjustment)
        )
    }

    var textAlignment: TextAlignment {
        if markerPoint.x < Self.labelWidth / 2 {
            return .leading
        }
        if markerPoint.x > containerWidth - Self.labelWidth / 2 {
            return .trailing
        }
        return .center
    }

    private func boundedY(_ y: CGFloat) -> CGFloat {
        let topBound = Self.labelHeight / 2 + 4
        let bottomBound = containerHeight - Self.labelHeight / 2 - 4
        return min(max(y, topBound), bottomBound)
    }

    private var curveAwareLabelDistance: CGFloat {
        let minimumClearance = Self.labelHeight / 2 + 12
        let preferredClearance = Self.labelHeight / 2 + 18
        let availableSpace = verticalDirection == .above
            ? markerPoint.y - (Self.labelHeight / 2 + 4)
            : containerHeight - markerPoint.y - (Self.labelHeight / 2 + 4)

        guard availableSpace > minimumClearance else {
            return max(minimumClearance, availableSpace)
        }

        return min(preferredClearance, availableSpace)
    }

    private var curveAvoidanceOffset: CGFloat {
        guard !usesGuideLine, !isAxisLevel, verticalDirection == .above else {
            return 0
        }

        let nearLeftCurve = markerPoint.x < containerWidth * 0.35
        let nearRightCurve = markerPoint.x > containerWidth * 0.65

        if nearLeftCurve {
            return -Self.labelWidth * 0.34
        }
        if nearRightCurve {
            return Self.labelWidth * 0.34
        }
        return 0
    }
}

private struct RhythmPointMarker: View {
    enum Placement {
        case above
        case below
        case axisBelow

        var verticalDirection: MarkerLayout.VerticalDirection {
            self == .above ? .above : .below
        }

        var isAxisLevel: Bool {
            self == .axisBelow
        }
    }

    let time: String
    let title: String
    let coordinate: CGPoint
    let placement: Placement
    let accentColor: Color
    let showGuideLine: Bool
    let containerWidth: CGFloat
    let containerHeight: CGFloat
    var isCurrentState: Bool = false
    var verticalAdjustment: CGFloat = 0
    var labelHorizontalAdjustment: CGFloat = 0
    var textAlignmentOverride: TextAlignment?
    @State private var isPulsing = false

    private let markerSize: CGFloat = 5

    private var layout: MarkerLayout {
        MarkerLayout(
            markerPoint: coordinate,
            labelAlignment: .center,
            verticalDirection: placement.verticalDirection,
            isAxisLevel: placement.isAxisLevel,
            usesGuideLine: showGuideLine,
            verticalAdjustment: verticalAdjustment,
            labelHorizontalAdjustment: labelHorizontalAdjustment,
            containerWidth: containerWidth,
            containerHeight: containerHeight)
    }

    var body: some View {
        ZStack {
            if showGuideLine {
                RhythmGuideLine(
                    from: layout.markerPoint,
                    to: layout.guideEnd,
                    tint: accentColor,
                    isPulsing: isCurrentState && isPulsing)
            }

            Circle()
                .fill(accentColor.opacity(isCurrentState && isPulsing ? 0.92 : 0.76))
                .frame(width: markerSize, height: markerSize)
                .shadow(
                    color: accentColor.opacity(isCurrentState && isPulsing ? 0.50 : 0.28),
                    radius: isCurrentState && isPulsing ? 9 : 5)
                .position(layout.markerPoint)

            RhythmMarkerLabel(
                time: time,
                title: title,
                tint: accentColor.opacity(showGuideLine ? 0.78 : 0.72),
                isPulsing: isCurrentState && isPulsing,
                textAlignment: textAlignmentOverride ?? layout.textAlignment)
                .position(layout.labelPosition)
        }
        .animation(
            isCurrentState
                ? .easeInOut(duration: 2.8).repeatForever(autoreverses: true)
                : nil,
            value: isPulsing)
        .onAppear {
            guard isCurrentState else { return }
            isPulsing = true
        }
        .onDisappear {
            isPulsing = false
        }
    }
}

private struct RhythmMarkerLabel: View {
    let time: String
    let title: String
    let tint: Color
    var isPulsing: Bool = false
    var textAlignment: TextAlignment = .center

    var body: some View {
        VStack(spacing: 1) {
            Text(time)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(tint.opacity(isPulsing ? 0.86 : 0.76))
            Text(title)
                .font(.system(size: 11, weight: .regular, design: .rounded))
                .foregroundStyle(tint.opacity(isPulsing ? 0.76 : 0.64))
        }
        .multilineTextAlignment(textAlignment)
        .frame(width: MarkerLayout.labelWidth, height: MarkerLayout.labelHeight)
        .shadow(color: .black.opacity(0.20), radius: 3, y: 1)
    }
}

private struct RhythmGuideLine: View {
    let from: CGPoint
    let to: CGPoint
    let tint: Color
    let isPulsing: Bool

    var body: some View {
        Path { path in
            path.move(to: from)
            path.addLine(to: to)
        }
        .stroke(
            tint.opacity(isPulsing ? 0.62 : 0.40),
            style: StrokeStyle(lineWidth: 1, lineCap: .round, dash: [4, 5]))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private func rhythmTimeLabel(_ hour: Double) -> String {
    let normalized = ((hour.truncatingRemainder(dividingBy: 24)) + 24).truncatingRemainder(dividingBy: 24)
    let totalMinutes = Int(round(normalized * 60)) % (24 * 60)
    let wholeHour = totalMinutes / 60
    let minute = totalMinutes % 60
    return String(format: "%02d:%02d", wholeHour, minute)
}

struct DailyRhythmView_Previews: PreviewProvider {
    static var previews: some View {
        DailyRhythmView(
            sunriseHour: 7.03,
            sunsetHour: 18.5,
            sleepStartHour: 23,
            wakeHour: 7)
            .padding()
            .background(NightBackground())
            .preferredColorScheme(.dark)
    }
}
