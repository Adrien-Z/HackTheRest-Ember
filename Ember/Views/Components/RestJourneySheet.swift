import SwiftUI

struct RestJourneySheet: View {
    @EnvironmentObject private var store: DataStore
    let expandedHeight: CGFloat?
    @State private var fabricOpacity = 0.0
    @State private var fabricScaleY = 0.02
    @State private var bottomFoldOffset: CGFloat = 0
    @State private var contentVisible = false

    init(expandedHeight: CGFloat? = nil) {
        self.expandedHeight = expandedHeight
    }

    private let dailyMoments = [
        JourneyPointEvent(id: "daily_check_in", title: "Daily check-in",
                          detail: "Synced once per UTC+8 day", points: 20),
        JourneyPointEvent(id: "rested_well", title: "Rested well last night",
                          detail: "7h sleep with at least 80% efficiency", points: 30),
        JourneyPointEvent(id: "wind_down_completed", title: "Wind-down ritual completed",
                          detail: "Tap to confirm your personal ritual", points: 30),
        JourneyPointEvent(id: "rhythm_kept", title: "Kept your sleep rhythm",
                          detail: "Stable sleep timing across recent nights", points: 50)
    ]

    private var milestones: [JourneyMilestone] {
        let restDays = Array(store.restJourney.dailyScores.values)
            .filter { ($0.sleepMinutes ?? 0) >= 300 }.count
        return [
            JourneyMilestone(
                title: "10 Days of Rest",
                caption: "Sleep 5+ hours on 10 tracked nights",
                progressText: "\(min(restDays, 10))/10",
                isUnlocked: store.completedPointEvents.contains("ten_days_rest")),
            JourneyMilestone(
                title: "Rhythm Keeper",
                caption: "Keep a stable rhythm for 7 consecutive nights",
                progressText: store.completedPointEvents.contains("rhythm_keeper") ? "Unlocked" : "In progress",
                isUnlocked: store.completedPointEvents.contains("rhythm_keeper"))
        ]
    }

    var body: some View {
        GeometryReader { proxy in
            let targetHeight = expandedHeight ?? proxy.size.height
            ZStack(alignment: .top) {
                ZStack(alignment: .top) {
                    NightBackground()

                    RestSheetBackground(
                        opacity: fabricOpacity,
                        scaleY: fabricScaleY,
                        bottomFoldOffset: bottomFoldOffset,
                        targetSize: CGSize(width: proxy.size.width, height: targetHeight),
                    )

                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 18) {
                            header
                            todaysMomentsSection
                            upcomingMomentsSection
                            milestonesSection
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 18)
                        .padding(.bottom, 26)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .opacity(contentVisible ? 1 : 0)

                    // Keep the fabric's top and bottom edge above the scrolling
                    // cards, so items dissolve into the sheet instead of hitting
                    // a hard clipped boundary.
                    RestJourneyContentEdgeFog(opacity: fabricOpacity)
                        .opacity(contentVisible ? 1 : 0)
                        .allowsHitTesting(false)
                }
                .frame(width: proxy.size.width, height: targetHeight, alignment: .top)
                .clipped()
            }
            .frame(width: proxy.size.width, height: targetHeight, alignment: .top)
            .onAppear {
                fabricOpacity = 0
                fabricScaleY = 0.02
                bottomFoldOffset = 0
                contentVisible = false

                withAnimation(.spring(response: 0.78, dampingFraction: 0.78)) {
                    fabricOpacity = 1
                    fabricScaleY = 1.035
                }

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.58) {
                    withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) {
                        fabricScaleY = 1
                    }
                }

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.72) {
                    withAnimation(.easeOut(duration: 0.28)) {
                        contentVisible = true
                    }
                    withAnimation(.easeInOut(duration: 0.34)) {
                        bottomFoldOffset = 3
                    }
                }

                DispatchQueue.main.asyncAfter(deadline: .now() + 1.08) {
                    withAnimation(.easeOut(duration: 0.42)) {
                        bottomFoldOffset = 0
                    }
                }
            }
        }
        .frame(height: expandedHeight)
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(store.displayName)'s Rest Journey")
                        .font(.title2.weight(.bold))
                    Text(Date.now.formatted(.dateTime.month(.wide).year()))
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Theme.secondaryText)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text("\(store.restJourney.points.formatted()) Rest Points")
                        .font(.system(.largeTitle, design: .rounded).weight(.bold))
                        .foregroundStyle(Color(red: 0.61, green: 0.85, blue: 1.0))
                    Text("Synced from HealthKit-qualified Supabase rewards")
                        .font(.footnote)
                        .foregroundStyle(Theme.secondaryText)
                }
            }
            Spacer(minLength: 4)
            BoxSkinImageView(
                decoration: store.selectedBoxDecoration,
                size: CGSize(width: 78, height: 72))
                .accessibilityLabel(store.selectedBoxDecoration?.name ?? "Simple Blue Box")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .emberCard()
    }

    private var todaysMomentsSection: some View {
        JourneySection(title: "Today's Moments") {
            VStack(spacing: 12) {
                ForEach(dailyMoments) { moment in
                    JourneyMomentRow(
                        title: moment.title,
                        detail: moment.detail,
                        points: moment.points,
                        isComplete: store.completedPointEvents.contains(moment.id),
                        action: moment.id == "wind_down_completed" ? {
                            Task { await store.completeWindDown() }
                        } : nil)
                }

                Divider().overlay(Color.white.opacity(0.08))

                HStack {
                    Text("Today's collection")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Text("+\(todayAwardedPoints) pts")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(Theme.mint)
                }
            }
        }
    }

    private var upcomingMomentsSection: some View {
        JourneySection(title: "Health Data Used Locally") {
            VStack(spacing: 12) {
                if let day = store.todayRestPointDay {
                    HealthSignalRow(label: "Steps", value: day.steps.formatted())
                    HealthSignalRow(label: "Active energy", value: "\(day.activeEnergyKcal.formatted()) kcal")
                    HealthSignalRow(label: "Exercise", value: "\(day.exerciseMinutes.formatted()) min")
                } else {
                    Text("Connect Apple Health to qualify for health-based rewards.")
                        .font(.subheadline)
                        .foregroundStyle(Theme.secondaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    private var todayAwardedPoints: Int {
        dailyMoments
            .filter { store.completedPointEvents.contains($0.id) }
            .reduce(0) { $0 + $1.points }
    }

    private var milestonesSection: some View {
        JourneySection(title: "Milestones") {
            VStack(spacing: 12) {
                ForEach(milestones) { milestone in
                    JourneyMilestoneRow(milestone: milestone)
                }
            }
        }
    }
}

private struct RestJourneyContentEdgeFog: View {
    let opacity: Double

    var body: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(.ultraThinMaterial)
                .overlay(Color(red: 0.025, green: 0.045, blue: 0.085).opacity(0.72))
                .compositingGroup()
                .mask(
                    LinearGradient(
                        colors: [.black.opacity(0.94), .clear],
                        startPoint: .top,
                        endPoint: .bottom)
                )
                .frame(height: 58)
                .blur(radius: 0.6)

            Spacer(minLength: 0)

            Rectangle()
                .fill(.ultraThinMaterial)
                .overlay(Color(red: 0.015, green: 0.030, blue: 0.065).opacity(0.82))
                .compositingGroup()
                .mask(
                    LinearGradient(
                        colors: [.clear, .black.opacity(0.96)],
                        startPoint: .top,
                        endPoint: .bottom)
                )
                .frame(height: 86)
                .blur(radius: 0.8)
        }
        .opacity(opacity * 0.9)
    }
}

private struct RestSheetBackground: View {
    let opacity: Double
    let scaleY: CGFloat
    let bottomFoldOffset: CGFloat
    let targetSize: CGSize

    var body: some View {
        ZStack {
            Image("RestSheet")
                .resizable()
                .scaledToFill()
                .frame(
                    width: targetSize.width,
                    height: targetSize.height,
                    alignment: .top)
                .opacity(opacity)
                .shadow(
                    color: Color.black.opacity(opacity > 0 ? 0.20 : 0),
                    radius: opacity > 0 ? 18 : 0,
                    y: 8)

            LinearGradient(
                colors: [
                    Color.white.opacity(opacity > 0 ? 0.11 : 0),
                    Color.white.opacity(0.015),
                    Color.black.opacity(0.16)
                ],
                startPoint: .top,
                endPoint: .bottom)
                .opacity(opacity)
                .blendMode(.softLight)

            VStack(spacing: 0) {
                topConnectionShadow
                Spacer()
            }

            VStack(spacing: 0) {
                fabricHighlight
                Spacer()
            }
        }
        .frame(
            width: targetSize.width,
            height: targetSize.height,
            alignment: .top)
        .scaleEffect(x: 1, y: scaleY, anchor: .top)
        .mask(clothMask)
        .overlay {
            ClothSilhouette()
                .stroke(Color.white.opacity(0.055), lineWidth: 1)
                .blur(radius: 0.8)
                .scaleEffect(x: 1, y: scaleY, anchor: .top)
                .opacity(opacity)
        }
        .overlay(alignment: .top) {
            topFabricOverlap
        }
        .overlay(alignment: .bottom) {
            bottomFold
        }
    }

    private var bottomFold: some View {
        LinearGradient(
            colors: [
                Color.white.opacity(0.16),
                Theme.boxBlue.opacity(0.08),
                Color.black.opacity(0.10)
            ],
            startPoint: .top,
            endPoint: .bottom)
        .frame(height: 64)
        .blur(radius: 0.4)
        .opacity(opacity * 0.8)
        .offset(y: bottomFoldOffset)
    }

    private var topConnectionShadow: some View {
        LinearGradient(
            colors: [
                Color.black.opacity(0.28),
                Theme.boxBlue.opacity(0.10),
                Color.clear
            ],
            startPoint: .top,
            endPoint: .bottom)
        .frame(height: 58)
        .blur(radius: 12)
        .opacity(opacity)
        .offset(y: -14)
    }

    private var fabricHighlight: some View {
        LinearGradient(
            colors: [
                Color.white.opacity(0.10),
                Color.white.opacity(0.035),
                Color.clear
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing)
        .frame(height: targetSize.height * 0.46)
        .opacity(opacity)
    }

    private var clothMask: some View {
        ClothSilhouette()
            .fill(
                LinearGradient(
                    stops: [
                        .init(color: .black.opacity(0.10), location: 0),
                        .init(color: .black.opacity(0.78), location: 0.035),
                        .init(color: .black, location: 0.12),
                        .init(color: .black, location: 1)
                    ],
                    startPoint: .top,
                    endPoint: .bottom))
            .blur(radius: 0.65)
    }

    private var topFabricOverlap: some View {
        Image("RestSheet")
            .resizable()
            .scaledToFill()
            .frame(width: targetSize.width, height: 42, alignment: .top)
            .clipShape(TopTuckShape())
            .blur(radius: 3.0)
            .opacity(opacity * 0.64)
            .offset(y: 1)
            .shadow(color: Color.black.opacity(opacity * 0.18), radius: 8, y: 5)
    }
}

private struct ClothSilhouette: Shape {
    func path(in rect: CGRect) -> Path {
        let topRadius = min(rect.width * 0.16, 54)
        let bottomRadius = min(rect.width * 0.10, 30)
        let sideInset = rect.width * 0.025
        let lowerSideInset = rect.width * 0.012

        var path = Path()
        path.move(to: CGPoint(x: rect.minX + topRadius, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - topRadius, y: rect.minY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX - sideInset, y: rect.minY + topRadius),
            control: CGPoint(x: rect.maxX - sideInset * 0.5, y: rect.minY + 2))
        path.addCurve(
            to: CGPoint(x: rect.maxX - lowerSideInset, y: rect.maxY - bottomRadius),
            control1: CGPoint(x: rect.maxX - sideInset * 1.8, y: rect.midY * 0.72),
            control2: CGPoint(x: rect.maxX + sideInset * 0.8, y: rect.midY * 1.28))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX - bottomRadius, y: rect.maxY),
            control: CGPoint(x: rect.maxX - lowerSideInset, y: rect.maxY - bottomRadius * 0.22))
        path.addLine(to: CGPoint(x: rect.minX + bottomRadius, y: rect.maxY))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + lowerSideInset, y: rect.maxY - bottomRadius),
            control: CGPoint(x: rect.minX + lowerSideInset, y: rect.maxY - bottomRadius * 0.22))
        path.addCurve(
            to: CGPoint(x: rect.minX + sideInset, y: rect.minY + topRadius),
            control1: CGPoint(x: rect.minX - sideInset * 0.8, y: rect.midY * 1.28),
            control2: CGPoint(x: rect.minX + sideInset * 1.8, y: rect.midY * 0.72))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + topRadius, y: rect.minY),
            control: CGPoint(x: rect.minX + sideInset * 0.5, y: rect.minY + 2))
        path.closeSubpath()
        return path
    }
}

private struct TopTuckShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + 22, y: rect.minY + 10))
        path.addCurve(
            to: CGPoint(x: rect.maxX - 22, y: rect.minY + 8),
            control1: CGPoint(x: rect.width * 0.30, y: rect.minY - 4),
            control2: CGPoint(x: rect.width * 0.70, y: rect.minY + 20))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.maxY),
            control: CGPoint(x: rect.maxX - 4, y: rect.minY + 18))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + 22, y: rect.minY + 10),
            control: CGPoint(x: rect.minX + 4, y: rect.minY + 18))
        path.closeSubpath()
        return path
    }
}

private struct JourneySection<Content: View>: View {
    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(.headline.weight(.semibold))
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .emberCard()
    }
}

private struct JourneyMomentRow: View {
    let title: String
    let detail: String
    let points: Int
    let isComplete: Bool
    let action: (() -> Void)?

    init(
        title: String,
        detail: String,
        points: Int,
        isComplete: Bool,
        action: (() -> Void)? = nil
    ) {
        self.title = title
        self.detail = detail
        self.points = points
        self.isComplete = isComplete
        self.action = action
    }

    var body: some View {
        Button {
            guard !isComplete else { return }
            Haptics.light()
            action?()
        } label: {
            HStack(spacing: 11) {
            Image(systemName: isComplete ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(isComplete ? Theme.mint : Color.secondary.opacity(0.65))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(isComplete ? Color.primary : Color.secondary)
                Text(detail)
                    .font(.caption2)
                    .foregroundStyle(Theme.secondaryText)
            }

            Spacer()

            if action != nil && !isComplete {
                Text("Mark done")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Theme.boxBlue)
            }
            Text("+\(points) pts")
                .font(.caption.weight(.bold))
                .foregroundStyle(isComplete ? Theme.mint : Color.secondary.opacity(0.7))
            }
            .opacity(isComplete ? 1 : (action == nil ? 0.62 : 0.88))
        }
        .buttonStyle(.plain)
        .disabled(action == nil || isComplete)
    }
}

private struct HealthSignalRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label).font(.subheadline)
            Spacer()
            Text(value).font(.caption.weight(.semibold)).foregroundStyle(Theme.secondaryText)
        }
    }
}

private struct JourneyPointEvent: Identifiable {
    let id: String
    let title: String
    let detail: String
    let points: Int
}

private struct JourneyMilestoneRow: View {
    let milestone: JourneyMilestone

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: milestone.isUnlocked ? "checkmark.seal.fill" : "lock.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(milestone.isUnlocked ? Theme.boxBlue : Color.secondary.opacity(0.7))
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 3) {
                Text(milestone.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(milestone.isUnlocked ? Color.primary : Color.secondary)
                Text(milestone.caption)
                    .font(.caption)
                    .foregroundStyle(Theme.secondaryText)
            }

            Spacer()

            Text(milestone.progressText)
                .font(.caption.weight(.bold))
                .foregroundStyle(milestone.isUnlocked ? Theme.mint : Color.secondary.opacity(0.7))
        }
        .padding(12)
        .background(
            milestone.isUnlocked ? Color.white.opacity(0.045) : Color.white.opacity(0.025),
            in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.white.opacity(milestone.isUnlocked ? 0.07 : 0.04), lineWidth: 1))
    }
}

private struct JourneyMilestone: Identifiable {
    var id: String { title }
    let title: String
    let caption: String
    let progressText: String
    let isUnlocked: Bool
}

struct RestJourneySheet_Previews: PreviewProvider {
    static var previews: some View {
        RestJourneySheet()
            .environmentObject(DataStore())
            .preferredColorScheme(.dark)
    }
}
