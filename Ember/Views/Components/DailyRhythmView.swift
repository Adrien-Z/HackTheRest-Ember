//
//  DailyRhythmView.swift
//  Ember
//
//  Created by Ivy on 2026/7/25.
//
import SwiftUI

struct DailyRhythmView: View {
    @ObservedObject private var weatherManager = WeatherManager.shared

    private let fallbackSunriseHour = 5.08
    private let fallbackSunsetHour = 21.0
    private let sleepHour = 23.0
    private let wakeHour = 7.0

    private var weatherRhythmData: WeatherRhythmData? {
        weatherManager.rhythmData
    }

    private var sunriseHour: Double {
        weatherRhythmData?.sunriseHour ?? fallbackSunriseHour
    }

    private var sunsetHour: Double {
        weatherRhythmData?.sunsetHour ?? fallbackSunsetHour
    }

    var body: some View {
        GeometryReader { proxy in
            let geometry = RhythmGeometry(
                size: proxy.size,
                sunriseHour: sunriseHour,
                sunsetHour: sunsetHour)

            ZStack {
                RhythmSkyBackground(geometry: geometry)
                RhythmCurveCanvas(geometry: geometry)
                RhythmMarkerLayer(
                    geometry: geometry,
                    sunriseHour: sunriseHour,
                    sunsetHour: sunsetHour,
                    sleepHour: sleepHour,
                    wakeHour: wakeHour)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .frame(height: 260)
        .task {
            await weatherManager.refreshWeather()
        }
    }
}

private struct RhythmGeometry {
    let size: CGSize
    let sunriseHour: Double
    let sunsetHour: Double

    var horizonY: CGFloat { size.height * 0.58 }
    var amplitude: CGFloat { size.height * 0.30 }
    var dayDuration: Double { max(0.1, sunsetHour - sunriseHour) }
    var nightDuration: Double { max(0.1, 24 - dayDuration) }

    func point(for hour: Double) -> CGPoint {
        let angle = angle(for: hour)
        return CGPoint(
            x: size.width * CGFloat(angle / (.pi * 2)),
            y: horizonY - amplitude * CGFloat(sin(angle)))
    }

    func point(forAngle angle: Double) -> CGPoint {
        CGPoint(
            x: size.width * CGFloat(angle / (.pi * 2)),
            y: horizonY - amplitude * CGFloat(sin(angle)))
    }

    func angle(for hour: Double) -> Double {
        let cycleHour = hour >= sunriseHour ? hour - sunriseHour : hour + 24 - sunriseHour
        if cycleHour <= dayDuration {
            return cycleHour / dayDuration * .pi
        }

        return .pi + (cycleHour - dayDuration) / nightDuration * .pi
    }
}

private struct RhythmSkyBackground: View {
    let geometry: RhythmGeometry

    var body: some View {
        Canvas { context, size in
            var background = Path()
            background.addRect(CGRect(origin: .zero, size: size))
            context.fill(
                background,
                with: .linearGradient(
                    Gradient(colors: [
                        Color(red: 0.015, green: 0.035, blue: 0.080),
                        Color(red: 0.020, green: 0.050, blue: 0.120),
                        Color(red: 0.010, green: 0.018, blue: 0.055)
                    ]),
                    startPoint: CGPoint(x: size.width / 2, y: 0),
                    endPoint: CGPoint(x: size.width / 2, y: size.height)))

            drawGlow(
                context: context,
                center: geometry.point(forAngle: 0),
                radius: size.width * 0.34,
                color: Color(red: 1.0, green: 0.72, blue: 0.28),
                opacity: 0.28)

            drawGlow(
                context: context,
                center: geometry.point(forAngle: .pi),
                radius: size.width * 0.32,
                color: Color(red: 1.0, green: 0.34, blue: 0.22),
                opacity: 0.22)

            drawGlow(
                context: context,
                center: geometry.point(forAngle: .pi * 1.5),
                radius: size.width * 0.34,
                color: Color(red: 0.30, green: 0.36, blue: 1.0),
                opacity: 0.20)

            drawStars(context: context, size: size)
        }
    }

    private func drawGlow(
        context: GraphicsContext,
        center: CGPoint,
        radius: CGFloat,
        color: Color,
        opacity: Double
    ) {
        var glow = Path()
        glow.addEllipse(in: CGRect(
            x: center.x - radius,
            y: center.y - radius,
            width: radius * 2,
            height: radius * 2))
        context.fill(
            glow,
            with: .radialGradient(
                Gradient(colors: [color.opacity(opacity), .clear]),
                center: center,
                startRadius: 1,
                endRadius: radius))
    }

    private func drawStars(context: GraphicsContext, size: CGSize) {
        let stars = [
            CGPoint(x: size.width * 0.12, y: size.height * 0.16),
            CGPoint(x: size.width * 0.28, y: size.height * 0.10),
            CGPoint(x: size.width * 0.66, y: size.height * 0.18),
            CGPoint(x: size.width * 0.82, y: size.height * 0.13),
            CGPoint(x: size.width * 0.91, y: size.height * 0.28)
        ]

        for star in stars {
            var dot = Path()
            dot.addEllipse(in: CGRect(x: star.x, y: star.y, width: 1.6, height: 1.6))
            context.fill(dot, with: .color(Color.white.opacity(0.32)))
        }
    }
}

private struct RhythmCurveCanvas: View {
    let geometry: RhythmGeometry

    var body: some View {
        Canvas { context, size in
            let horizon = horizonPath(width: size.width)
            let dayPath = curvePath(from: 0, to: .pi)
            let nightPath = curvePath(from: .pi, to: .pi * 2)

            context.stroke(
                horizon,
                with: .linearGradient(
                    Gradient(colors: [
                        Color.white.opacity(0.18),
                        Color(red: 1.0, green: 0.76, blue: 0.36).opacity(0.44),
                        Color(red: 0.48, green: 0.50, blue: 1.0).opacity(0.40),
                        Color.white.opacity(0.16)
                    ]),
                    startPoint: CGPoint(x: 0, y: geometry.horizonY),
                    endPoint: CGPoint(x: size.width, y: geometry.horizonY)),
                lineWidth: 0.8)

            strokeGlow(
                context: context,
                path: dayPath,
                colors: [
                    Color(red: 1.0, green: 0.82, blue: 0.38).opacity(0.18),
                    Color(red: 1.0, green: 0.48, blue: 0.24).opacity(0.14)
                ],
                start: geometry.point(forAngle: 0),
                end: geometry.point(forAngle: .pi))

            strokeGlow(
                context: context,
                path: nightPath,
                colors: [
                    Color(red: 0.70, green: 0.42, blue: 1.0).opacity(0.16),
                    Color(red: 0.30, green: 0.52, blue: 1.0).opacity(0.18)
                ],
                start: geometry.point(forAngle: .pi),
                end: geometry.point(forAngle: .pi * 2))

            context.stroke(
                dayPath,
                with: .linearGradient(
                    Gradient(colors: [
                        Color(red: 1.0, green: 0.86, blue: 0.44),
                        Color(red: 1.0, green: 0.54, blue: 0.28)
                    ]),
                    startPoint: geometry.point(forAngle: 0),
                    endPoint: geometry.point(forAngle: .pi)),
                style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round))

            context.stroke(
                nightPath,
                with: .linearGradient(
                    Gradient(colors: [
                        Color(red: 0.74, green: 0.46, blue: 1.0),
                        Color(red: 0.34, green: 0.56, blue: 1.0)
                    ]),
                    startPoint: geometry.point(forAngle: .pi),
                    endPoint: geometry.point(forAngle: .pi * 2)),
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
            let point = geometry.point(forAngle: angle)
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

private struct RhythmMarkerLayer: View {
    let geometry: RhythmGeometry
    let sunriseHour: Double
    let sunsetHour: Double
    let sleepHour: Double
    let wakeHour: Double

    var body: some View {
        ZStack {
            RhythmMarker(
                title: "Sunrise",
                time: rhythmTimeLabel(sunriseHour),
                point: geometry.point(forAngle: 0),
                placement: .below,
                containerSize: geometry.size,
                labelHorizontalOffset: 10,
                color: Color(red: 1.0, green: 0.82, blue: 0.38))

            RhythmMarker(
                title: "Sunset",
                time: rhythmTimeLabel(sunsetHour),
                point: geometry.point(forAngle: .pi),
                placement: .above,
                containerSize: geometry.size,
                color: Color(red: 1.0, green: 0.55, blue: 0.28))

            RhythmMarker(
                title: "Sleep",
                time: rhythmTimeLabel(sleepHour),
                point: geometry.point(for: sleepHour),
                placement: .below,
                containerSize: geometry.size,
                color: Color(red: 0.74, green: 0.56, blue: 1.0),
                showsGuide: true)

            RhythmMarker(
                title: "Wake",
                time: rhythmTimeLabel(wakeHour),
                point: geometry.point(for: wakeHour),
                placement: .above,
                containerSize: geometry.size,
                color: Color(red: 1.0, green: 0.82, blue: 0.42))
        }
    }
}

private struct RhythmMarker: View {
    enum Placement {
        case above
        case below

        var direction: CGFloat {
            self == .above ? -1 : 1
        }
    }

    let title: String
    let time: String
    let point: CGPoint
    let placement: Placement
    let containerSize: CGSize
    var labelHorizontalOffset: CGFloat = 0
    let color: Color
    var showsGuide = false

    private let edgePadding: CGFloat = 12
    private let labelWidth: CGFloat = 76
    private let labelDistance: CGFloat = 36
    private let guideLength: CGFloat = 22

    var body: some View {
        ZStack {
            if showsGuide {
                RhythmGuideLine(from: point, to: guideEnd, color: color)
            }

            Circle()
                .fill(color.opacity(0.86))
                .frame(width: 5, height: 5)
                .shadow(color: color.opacity(0.45), radius: 8)
                .position(point)

            VStack(spacing: 1) {
                Text(time)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(color.opacity(0.82))
                    .multilineTextAlignment(textAlignment)
                Text(title)
                    .font(.system(size: 11, weight: .regular, design: .rounded))
                    .foregroundStyle(color.opacity(0.68))
                    .multilineTextAlignment(textAlignment)
            }
            .frame(width: labelWidth, alignment: frameAlignment)
            .shadow(color: .black.opacity(0.24), radius: 4, y: 2)
            .position(labelPoint)
        }
    }

    private var guideEnd: CGPoint {
        CGPoint(x: point.x, y: point.y + placement.direction * guideLength)
    }

    private var labelPoint: CGPoint {
        CGPoint(x: labelCenterX + labelHorizontalOffset, y: point.y + placement.direction * labelDistance)
    }

    private var labelCenterX: CGFloat {
        let halfWidth = labelWidth / 2
        if point.x - halfWidth < edgePadding {
            return point.x + halfWidth
        }

        if point.x + halfWidth > containerSize.width - edgePadding {
            return point.x - halfWidth
        }

        return point.x
    }

    private var textAlignment: TextAlignment {
        let halfWidth = labelWidth / 2
        if point.x - halfWidth < edgePadding {
            return .leading
        }

        if point.x + halfWidth > containerSize.width - edgePadding {
            return .trailing
        }

        return .center
    }

    private var frameAlignment: Alignment {
        let halfWidth = labelWidth / 2
        if point.x - halfWidth < edgePadding {
            return .leading
        }

        if point.x + halfWidth > containerSize.width - edgePadding {
            return .trailing
        }

        return .center
    }
}

private struct RhythmGuideLine: View {
    let from: CGPoint
    let to: CGPoint
    let color: Color

    var body: some View {
        Path { path in
            path.move(to: from)
            path.addLine(to: to)
        }
        .stroke(
            color.opacity(0.42),
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

#Preview {
    DailyRhythmView()
        .padding()
        .background(Color(red: 0.006, green: 0.014, blue: 0.040))
        .preferredColorScheme(.dark)
}
