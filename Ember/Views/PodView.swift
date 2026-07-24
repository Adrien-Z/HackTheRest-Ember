import SwiftUI

struct BoxSpaceView: View {
    @EnvironmentObject private var store: DataStore
    @State private var selectedPerson: BoxSpacePerson?
    @State private var showDecorationStudio = false
    @State private var openStudioAfterSheetDismisses = false

    @State private var showRestJourney = false
    @StateObject private var friendsViewModel = FriendsViewModel()
    @State private var showAddFriend = false

    private var snapshot: BoxSpaceSnapshot { store.boxSpace }
    private var everyone: [BoxSpacePerson] {
        let friends = friendsViewModel.friends.map {
            BoxSpacePerson(
                id: $0.userId.uuidString,
                name: $0.displayName,
                monthlyScore: 0,
                rank: 0,
                isFriend: true,
                isCurrentUser: false,
                decorationID: nil
            )
        }
        let friendIDs = Set(friends.map(\.id))
        // Keep backend-provided box metadata (such as score and decoration)
        // when available, while never showing bundled example friends.
        let boxPeople = snapshot.people.filter { person in
            !person.isFriend || !friendIDs.contains(person.id)
        }
        return [snapshot.currentUser] + friends + boxPeople
    }

    var body: some View {
        ZStack {
            BoxWorldCanvas(
                people: everyone,
                decorations: snapshot.decorations,
                selectedPerson: $selectedPerson
            )
            // Let the map continue underneath the system's glass tab bar, so
            // it reads as a floating control instead of a hard canvas edge.
            .ignoresSafeArea(edges: [.top, .bottom])

            VStack(spacing: 10) {
                scoreCard
                if showRestJourney {
                    GeometryReader { proxy in
                        RestJourneySheet(expandedHeight: proxy.size.height) {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                showRestJourney = false
                            }
                        }
                    }
                }
                if !showRestJourney {
                    socialActions
                        .transition(.opacity)
                }

                Spacer()

            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
        }
        .toolbar(.hidden, for: .navigationBar)
        .sheet(item: $selectedPerson, onDismiss: {
            guard openStudioAfterSheetDismisses else { return }
            openStudioAfterSheetDismisses = false
            showDecorationStudio = true
        }) { person in
            BoxProfileSheet(
                person: person,
                decoration: snapshot.decorations.first { $0.id == person.decorationID },
                onDecorate: person.isCurrentUser ? {
                    openStudioAfterSheetDismisses = true
                    selectedPerson = nil
                } : nil
            )
            .presentationDetents([.height(person.isCurrentUser ? 350 : 300)])
            .presentationDragIndicator(.visible)
        }
        .navigationDestination(isPresented: $showDecorationStudio) {
            BoxDecorationStudio()
        }
        .sheet(isPresented: $showAddFriend) {
            NavigationStack {
                AddFriendView(viewModel: friendsViewModel)
            }
        }
        .task { await friendsViewModel.refreshAll() }
    }

    private var scoreCard: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                showRestJourney.toggle()
            }
        } label: {
            HStack(spacing: 13) {
                ZStack(alignment: .bottomTrailing) {
                    BlueBoxMascot(isActive: true, isCurrentUser: false)
                        .scaleEffect(0.8)
                        .frame(width: 44, height: 40)
                    if let decoration = selectedDecoration {
                        Image(systemName: decoration.systemImage)
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(Theme.amber)
                            .padding(3)
                            .background(.regularMaterial, in: Circle())
                            .offset(x: 2, y: 1)
                    }
                }
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(snapshot.currentUser.name).font(.subheadline.weight(.bold))
                        Text(snapshot.monthLabel)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(snapshot.currentUser.monthlyScore.formatted())
                            .font(.system(.title3, design: .rounded).weight(.bold))
                        Text("sleep pts")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Divider().frame(height: 34)
                VStack(alignment: .trailing, spacing: 3) {
                    Text("Rank #\(snapshot.currentUser.rank)").font(.caption.weight(.bold))
                    Text("Resets \(resetLabel)").font(.caption2).foregroundStyle(.secondary)
                }
                if store.boxSpaceLoading { ProgressView().tint(Theme.boxBlue) }
            }
            .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(Color.white.opacity(0.13), lineWidth: 0.75)
        )
        .shadow(color: Color.black.opacity(0.22), radius: 14, y: 7)
        .buttonStyle(.plain)
    }

    private var socialActions: some View {
        HStack(spacing: 8) {
            NavigationLink {
                FriendRequestsView(viewModel: friendsViewModel)
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "person.badge.clock")
                        .font(.system(size: 12, weight: .semibold))
                        .frame(width: 14, height: 14)
                    Text("Requests")
                        .lineLimit(1)
                    if !friendsViewModel.incomingRequests.isEmpty {
                        Text("\(friendsViewModel.incomingRequests.count)")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .frame(minWidth: 16, minHeight: 16)
                            .background(Theme.boxBlue, in: Capsule())
                    }
                }
            }
            .buttonStyle(BoxSocialButtonStyle())

            Button { showAddFriend = true } label: {
                Image(systemName: "person.badge.plus")
                    .frame(width: 34, height: 34)
            }
            .buttonStyle(BoxSocialButtonStyle())
            .accessibilityLabel("Add Friend")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var selectedDecoration: BoxDecoration? {
        snapshot.decorations.first { $0.id == snapshot.currentUser.decorationID }
    }

    private var resetLabel: String {
        guard let date = ISO8601DateFormatter().date(from: snapshot.resetsAt) else {
            return "next month"
        }
        return date.formatted(.dateTime.month(.abbreviated).day())
    }
}

// MARK: - Draggable map

private struct BoxWorldCanvas: View {
    let people: [BoxSpacePerson]
    let decorations: [BoxDecoration]
    @Binding var selectedPerson: BoxSpacePerson?

    @State private var settledOffset: CGSize = .zero
    @State private var dragTranslation: CGSize = .zero

    var body: some View {
        GeometryReader { proxy in
            let layout = BoxWorldLayout(people: people, minimumSize: proxy.size)
            let proposed = CGSize(
                width: settledOffset.width + dragTranslation.width,
                height: settledOffset.height + dragTranslation.height)
            let offset = Self.rubberBanded(proposed, viewport: proxy.size, world: layout.worldSize)
            let origin = CGPoint(
                x: (proxy.size.width - layout.worldSize.width) / 2 + offset.width,
                y: (proxy.size.height - layout.worldSize.height) / 2 + offset.height)

            ZStack(alignment: .topLeading) {
                Self.mapGradient.contentShape(Rectangle())

                BoxWorldLayer(
                    items: layout.items,
                    decorations: decorations,
                    ringCount: layout.ringCount,
                    worldSize: layout.worldSize,
                    selectedPerson: $selectedPerson
                )
                .equatable()
                .frame(width: layout.worldSize.width, height: layout.worldSize.height)
                .background(Self.mapGradient)
                .offset(x: origin.x, y: origin.y)
            }
            .clipped()
            .contentShape(Rectangle())
            .simultaneousGesture(
                DragGesture(minimumDistance: 1)
                    .onChanged { value in
                        var transaction = Transaction()
                        transaction.disablesAnimations = true
                        withTransaction(transaction) {
                            dragTranslation = value.translation
                        }
                    }
                    .onEnded { value in
                        let momentum = Self.limitedMomentum(
                            predicted: value.predictedEndTranslation,
                            actual: value.translation,
                            viewport: proxy.size)
                        let target = CGSize(
                            width: settledOffset.width + value.translation.width + momentum.width,
                            height: settledOffset.height + value.translation.height + momentum.height)
                        let resting = Self.clamped(target, viewport: proxy.size, world: layout.worldSize)
                        // A single non-oscillating timing curve prevents the map
                        // from crossing the legal edge and bouncing back again.
                        withAnimation(.timingCurve(
                            0.20, 0.82, 0.30, 1.0,
                            duration: 0.26
                        )) {
                            settledOffset = resting
                            dragTranslation = .zero
                        }
                    }
            )
        }
    }

    private static var mapGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.08, green: 0.13, blue: 0.22),
                Color(red: 0.045, green: 0.06, blue: 0.11)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing)
    }

    private static func limits(viewport: CGSize, world: CGSize) -> CGSize {
        CGSize(
            width: max(0, (world.width - viewport.width) / 2),
            height: max(0, (world.height - viewport.height) / 2))
    }

    private static func clamped(_ offset: CGSize, viewport: CGSize, world: CGSize) -> CGSize {
        let limit = limits(viewport: viewport, world: world)
        return CGSize(
            width: min(max(offset.width, -limit.width), limit.width),
            height: min(max(offset.height, -limit.height), limit.height))
    }

    private static func rubberBanded(_ offset: CGSize, viewport: CGSize, world: CGSize) -> CGSize {
        let limit = limits(viewport: viewport, world: world)
        return CGSize(
            width: rubberBandedAxis(offset.width, limit: limit.width, dimension: max(1, viewport.width)),
            height: rubberBandedAxis(offset.height, limit: limit.height, dimension: max(1, viewport.height)))
    }

    private static func rubberBandedAxis(
        _ value: CGFloat,
        limit: CGFloat,
        dimension: CGFloat
    ) -> CGFloat {
        guard abs(value) > limit else { return value }
        let overshoot = abs(value) - limit
        let resisted = min(
            52,
            (1 - 1 / (overshoot * 0.30 / dimension + 1)) * dimension)
        return value.sign == .minus ? -limit - resisted : limit + resisted
    }

    private static func limitedMomentum(
        predicted: CGSize,
        actual: CGSize,
        viewport: CGSize
    ) -> CGSize {
        let maximumX = min(72, viewport.width * 0.18)
        let maximumY = min(72, viewport.height * 0.12)
        let rawX = (predicted.width - actual.width) * 0.12
        let rawY = (predicted.height - actual.height) * 0.12
        return CGSize(
            width: min(max(rawX, -maximumX), maximumX),
            height: min(max(rawY, -maximumY), maximumY))
    }
}

/// The expensive box and grid subtree is equatable, so drag-frame updates only
/// change its offset instead of rebuilding every box. Avoiding an offscreen
/// compositing texture also keeps memory bounded as the friend map grows.
private struct BoxWorldLayer: View, Equatable {
    let items: [BoxWorldLayout.Item]
    let decorations: [BoxDecoration]
    let ringCount: Int
    let worldSize: CGSize
    @Binding var selectedPerson: BoxSpacePerson?

    static func == (lhs: BoxWorldLayer, rhs: BoxWorldLayer) -> Bool {
        lhs.items == rhs.items
            && lhs.decorations == rhs.decorations
            && lhs.ringCount == rhs.ringCount
            && lhs.worldSize == rhs.worldSize
    }

    var body: some View {
        ZStack {
            BoxMapFloor(ringCount: ringCount)
            ForEach(items) { item in
                BoxResident(
                    person: item.person,
                    decoration: decorations.first { $0.id == item.person.decorationID }
                )
                .contentShape(Rectangle())
                .onTapGesture { selectedPerson = item.person }
                .position(item.point)
                .zIndex(item.point.y)
                .accessibilityAddTraits(.isButton)
                .accessibilityLabel(
                    item.person.isFriend
                        ? "\(item.person.name), friend, \(item.person.monthlyScore) points"
                        : "Empty box, not added"
                )
                .accessibilityAction { selectedPerson = item.person }
            }
        }
        .frame(width: worldSize.width, height: worldSize.height)
    }
}

private struct BoxMapFloor: View {
    let ringCount: Int

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Path { path in
                    let step: CGFloat = 54
                    stride(from: 0, through: proxy.size.width, by: step).forEach { x in
                        path.move(to: CGPoint(x: x, y: 0))
                        path.addLine(to: CGPoint(x: x, y: proxy.size.height))
                    }
                    stride(from: 0, through: proxy.size.height, by: step).forEach { y in
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: proxy.size.width, y: y))
                    }
                }
                .stroke(Color.white.opacity(0.025), lineWidth: 1)

                ForEach(1...max(1, ringCount), id: \.self) { ring in
                    Circle()
                        .stroke(
                            Theme.boxBlue.opacity(ring == 1 ? 0.10 : 0.055),
                            style: StrokeStyle(lineWidth: 1, dash: [5, 9]))
                        .frame(
                            width: CGFloat(ring) * BoxWorldLayout.ringSpacing * 2,
                            height: CGFloat(ring) * BoxWorldLayout.ringSpacing * 2)
                }
                Circle().fill(Theme.boxBlue.opacity(0.08)).frame(width: 22, height: 22)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
    }
}

private struct BoxWorldLayout {
    static let ringSpacing: CGFloat = 132
    private static let horizontalEdgeInset: CGFloat = 66
    private static let verticalEdgeInset: CGFloat = 82

    struct Item: Identifiable, Equatable {
        let person: BoxSpacePerson
        let point: CGPoint
        var id: String { person.id }
    }

    let items: [Item]
    let ringCount: Int
    let worldSize: CGSize

    init(people: [BoxSpacePerson], minimumSize: CGSize = .zero) {
        let outerRing = Self.ringAndSlot(for: max(0, people.count - 2)).ring
        ringCount = max(1, outerRing)
        let diameter = CGFloat(ringCount) * Self.ringSpacing * 2
        let width = max(
            diameter + Self.horizontalEdgeInset * 2,
            minimumSize.width + 2)
        let height = max(
            diameter + Self.verticalEdgeInset * 2,
            minimumSize.height + 2)
        worldSize = CGSize(width: width, height: height)
        let center = CGPoint(x: width / 2, y: height / 2)

        var generated: [Item] = []
        for (index, person) in people.enumerated() {
            if index == 0 {
                generated.append(Item(person: person, point: center))
                continue
            }
            let location = Self.ringAndSlot(for: index - 1)
            let seed = person.id.unicodeScalars.reduce(0) { ($0 &* 31) &+ Int($1.value) }
            let angleJitter = Double((seed % 15) - 7) * .pi / 180
            let radialJitter = CGFloat(((seed / 17) % 19) - 9)
            let angle = -.pi / 2
                + Double(location.slot) * (2 * .pi / Double(location.capacity))
                + angleJitter
            let radius = CGFloat(location.ring) * Self.ringSpacing + radialJitter
            generated.append(Item(
                person: person,
                point: CGPoint(
                    x: center.x + CGFloat(cos(angle)) * radius,
                    y: center.y + CGFloat(sin(angle)) * radius)))
        }
        items = generated
    }

    private static func ringAndSlot(for ordinal: Int) -> (ring: Int, slot: Int, capacity: Int) {
        var remaining = max(0, ordinal)
        var ring = 1
        var capacity = 6
        while remaining >= capacity {
            remaining -= capacity
            ring += 1
            capacity += 4
        }
        return (ring, remaining, capacity)
    }
}

// MARK: - Box appearance

private struct BoxResident: View {
    let person: BoxSpacePerson
    let decoration: BoxDecoration?

    var body: some View {
        VStack(spacing: 5) {
            ZStack(alignment: .topTrailing) {
                BlueBoxMascot(isActive: person.isFriend, isCurrentUser: person.isCurrentUser)
                    .frame(
                        width: person.isCurrentUser ? 78 : 66,
                        height: person.isCurrentUser ? 72 : 61)
                if let decoration, person.isFriend {
                    Image(systemName: decoration.systemImage)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Theme.amber)
                        .padding(5)
                        .background(Theme.card, in: Circle())
                        .offset(x: 5, y: -8)
                }
            }
            if person.isFriend {
                Text(person.isCurrentUser ? "You" : person.name)
                    .font(.caption.weight(.semibold))
                Text("\(person.monthlyScore.formatted()) pts")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 94)
        .padding(.vertical, 6)
        .background(
            person.isCurrentUser ? Theme.boxBlue.opacity(0.08) : Color.clear,
            in: RoundedRectangle(cornerRadius: 16))
    }
}

struct BlueBoxMascot: View {
    let isActive: Bool
    let isCurrentUser: Bool

    private var frontFill: AnyShapeStyle {
        isActive
            ? AnyShapeStyle(LinearGradient(
                colors: [Color(red: 0.47, green: 0.86, blue: 1.0), Color(red: 0.12, green: 0.51, blue: 0.92)],
                startPoint: .topLeading, endPoint: .bottomTrailing))
            : AnyShapeStyle(Color(red: 0.34, green: 0.36, blue: 0.41))
    }

    private var sideFill: AnyShapeStyle {
        isActive
            ? AnyShapeStyle(LinearGradient(
                colors: [Color(red: 0.12, green: 0.42, blue: 0.83), Theme.boxBlueDeep],
                startPoint: .topLeading, endPoint: .bottomTrailing))
            : AnyShapeStyle(Color(red: 0.23, green: 0.25, blue: 0.30))
    }

    private var lidFill: AnyShapeStyle {
        isActive
            ? AnyShapeStyle(LinearGradient(
                colors: [Color(red: 0.79, green: 0.94, blue: 1.0), Color(red: 0.31, green: 0.72, blue: 0.98)],
                startPoint: .topLeading, endPoint: .bottomTrailing))
            : AnyShapeStyle(Color(red: 0.46, green: 0.48, blue: 0.54))
    }

    var body: some View {
        ZStack {
            Ellipse()
                .fill(Color.black.opacity(isActive ? 0.18 : 0.12))
                .frame(width: 50, height: 9)
                .blur(radius: 4)
                .offset(y: 31)

            // The darker side panel gives the little box its soft 3D depth.
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .fill(sideFill)
                .frame(width: 43, height: 45)
                .offset(x: 10, y: 8)

            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(frontFill)
                .frame(width: 54, height: 45)
                .offset(x: -4, y: 8)
                .overlay(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.white.opacity(isActive ? 0.28 : 0.08), lineWidth: 0.8)
                        .frame(width: 54, height: 45)
                        .offset(x: -4, y: 8)
                }

            // Back and open flaps — the overlapping layers imitate a soft,
            // rounded parcel that has just opened.
            Capsule()
                .fill(lidFill)
                .frame(width: 48, height: 21)
                .rotationEffect(.degrees(3))
                .offset(x: 2, y: -18)
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(lidFill)
                .frame(width: 51, height: 20)
                .rotationEffect(.degrees(5))
                .offset(x: -9, y: -9)
                .shadow(color: Color.black.opacity(0.10), radius: 3, y: 2)
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(lidFill)
                .frame(width: 31, height: 20)
                .rotationEffect(.degrees(-28))
                .offset(x: 22, y: -9)
                .shadow(color: Color.black.opacity(0.10), radius: 3, y: 2)

            HStack(spacing: 14) {
                BoxSmile()
                    .stroke(faceColor, style: StrokeStyle(lineWidth: 2.8, lineCap: .round))
                    .frame(width: 11, height: 5)
                BoxSmile()
                    .stroke(faceColor, style: StrokeStyle(lineWidth: 2.8, lineCap: .round))
                    .frame(width: 11, height: 5)
            }
            .offset(x: -4, y: 7)
            BoxSmile()
                .stroke(faceColor, style: StrokeStyle(lineWidth: 2.4, lineCap: .round))
                .frame(width: 10, height: 5)
                .offset(x: -4, y: 16)
            HStack(spacing: 25) {
                Ellipse().fill(Color(red: 1.0, green: 0.67, blue: 0.67).opacity(isActive ? 0.9 : 0.25))
                    .frame(width: 11, height: 6)
                Ellipse().fill(Color(red: 1.0, green: 0.67, blue: 0.67).opacity(isActive ? 0.9 : 0.25))
                    .frame(width: 11, height: 6)
            }
            .offset(x: -4, y: 15)
        }
        .frame(width: 70, height: 70)
        .shadow(
            color: isCurrentUser ? Theme.boxBlue.opacity(0.55) : Color.black.opacity(0.25),
            radius: isCurrentUser ? 12 : 5,
            y: 5)
        .overlay(alignment: .topLeading) {
            if isCurrentUser {
                Text("ME")
                    .font(.system(size: 7, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 5).padding(.vertical, 3)
                    .background(Theme.boxBlueDeep, in: Capsule())
                    .offset(x: -2, y: -9)
            }
        }
    }

    private var faceColor: Color {
        isActive ? Color(red: 0.04, green: 0.16, blue: 0.40) : Color.black.opacity(0.38)
    }
}

private struct BoxSocialButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.caption.weight(.bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .frame(height: 34)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(Capsule().strokeBorder(Color.white.opacity(0.14), lineWidth: 0.75))
            .opacity(configuration.isPressed ? 0.68 : 1)
    }
}


private struct BoxSmile: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY),
            control: CGPoint(x: rect.midX, y: rect.maxY))
        return path
    }
}

// MARK: - Profile and decoration

private struct BoxProfileSheet: View {
    let person: BoxSpacePerson
    let decoration: BoxDecoration?
    let onDecorate: (() -> Void)?

    var body: some View {
        ZStack {
            NightBackground()
            VStack(spacing: 14) {
                BlueBoxMascot(isActive: person.isFriend, isCurrentUser: person.isCurrentUser)
                    .frame(width: 86, height: 80)
                Text(
                    person.isCurrentUser
                        ? "Your Blue Box"
                        : (person.isFriend ? person.name : "Empty Box")
                )
                    .font(.title3.weight(.bold))
                if person.isFriend {
                    HStack(spacing: 18) {
                        Label("\(person.monthlyScore.formatted()) pts", systemImage: "moon.stars.fill")
                        Label("#\(person.rank)", systemImage: "chart.bar.fill")
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.boxBlue)
                    if let decoration {
                        Label(decoration.name, systemImage: decoration.systemImage)
                            .font(.caption).foregroundStyle(.secondary)
                    }
                } else {
                    Label("No friend added", systemImage: "person.crop.circle.badge.plus")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                if let onDecorate {
                    Button(action: onDecorate) {
                        Label("Decorate my box", systemImage: "paintbrush.fill")
                            .font(.subheadline.weight(.bold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .foregroundStyle(.white)
                            .background(Theme.boxGradient, in: RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 22)
                }
            }
            .padding()
        }
    }
}

private struct BoxDecorationStudio: View {
    @EnvironmentObject private var store: DataStore

    private var selectedDecoration: BoxDecoration? {
        store.boxSpace.decorations.first {
            $0.id == store.boxSpace.currentUser.decorationID
        }
    }

    var body: some View {
        ZStack {
            NightBackground()
            ScrollView {
                VStack(spacing: 22) {
                    VStack(spacing: 12) {
                        ZStack(alignment: .topTrailing) {
                            BlueBoxMascot(isActive: true, isCurrentUser: true)
                                .frame(width: 130, height: 120)
                                .scaleEffect(1.35)
                            if let selectedDecoration {
                                Image(systemName: selectedDecoration.systemImage)
                                    .font(.title2.weight(.bold))
                                    .foregroundStyle(Theme.amber)
                                    .padding(10)
                                    .background(Theme.card, in: Circle())
                                    .offset(x: 8, y: -2)
                            }
                        }
                        Text(selectedDecoration?.name ?? "Simple Blue Box").font(.headline)
                        Text("\(store.boxSpace.currentUser.monthlyScore.formatted()) points this month")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .emberCard()

                    VStack(alignment: .leading, spacing: 14) {
                        SectionHeader(
                            title: "Your decorations",
                            subtitle: "Tap an unlocked item to equip it")
                        LazyVGrid(
                            columns: [GridItem(.flexible()), GridItem(.flexible())],
                            spacing: 12
                        ) {
                            decorationTile(
                                name: "No decoration",
                                systemImage: "shippingbox.fill",
                                requiredScore: 0,
                                id: nil)
                            ForEach(store.boxSpace.decorations) { item in
                                decorationTile(
                                    name: item.name,
                                    systemImage: item.systemImage,
                                    requiredScore: item.requiredScore,
                                    id: item.id)
                            }
                        }
                    }
                    .emberCard()
                }
                .padding()
            }
        }
        .navigationTitle("Decorate Box")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func decorationTile(
        name: String,
        systemImage: String,
        requiredScore: Int,
        id: String?
    ) -> some View {
        let unlocked = store.boxSpace.currentUser.monthlyScore >= requiredScore
        let selected = store.boxSpace.currentUser.decorationID == id
        return Button {
            store.selectBoxDecoration(id)
        } label: {
            VStack(spacing: 9) {
                ZStack {
                    RoundedRectangle(cornerRadius: 17, style: .continuous)
                        .fill(selected ? Theme.boxBlue.opacity(0.22) : Color.white.opacity(0.045))
                        .frame(height: 82)
                    Image(systemName: unlocked ? systemImage : "lock.fill")
                        .font(.title2)
                        .foregroundStyle(unlocked ? Theme.boxBlue : Color.secondary)
                    if selected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(Theme.mint)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                            .padding(8)
                    }
                }
                Text(name).font(.caption.weight(.semibold)).lineLimit(1)
                Text(unlocked ? (selected ? "Equipped" : "Unlocked") : "\(requiredScore.formatted()) pts")
                    .font(.caption2)
                    .foregroundStyle(unlocked ? Theme.mint : Color.secondary)
            }
        }
        .buttonStyle(.plain)
        .disabled(!unlocked)
    }
}
