import SwiftUI

/// M2 메인 화면 — "캐릭터가 사는 나만의 공간".
/// 내 캐릭터는 하단 중앙, 음악을 듣는 친구 캐릭터가 방 중단에 등장/퇴장한다.
/// 세션 로직은 전부 AppModel에 있고, 이 뷰는 상태를 읽어 그리기만 한다.
struct RoomView: View {
    @Environment(AppModel.self) private var app

    @AppStorage("myAccessory") private var myAccessory = ""
    @AppStorage("myRoomTheme") private var myRoomTheme = RoomTheme.cream.rawValue

    private var theme: RoomTheme { RoomTheme(rawValue: myRoomTheme) ?? .cream }

    var body: some View {
        NavigationStack {
            ZStack {
                background
                floorAndCharacters
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    connectionDot
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showCustomizeSheet = true
                    } label: {
                        Image(systemName: "paintpalette")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showDebugPanel = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
            .sheet(isPresented: $showDebugPanel) {
                DebugPanelView()
            }
            .sheet(isPresented: $showCustomizeSheet) {
                CustomizeSheet()
            }
            // night 같은 어두운 테마에서 텍스트 대비 유지
            .environment(\.colorScheme, theme.isDark ? .dark : .light)
        }
    }

    @State private var showDebugPanel = false
    @State private var showCustomizeSheet = false

    // MARK: - 배경 (테마)

    private var background: some View {
        LinearGradient(colors: theme.wallColors, startPoint: .top, endPoint: .bottom)
            .ignoresSafeArea()
    }

    // MARK: - 방 (바닥 + 캐릭터)

    private var floorAndCharacters: some View {
        GeometryReader { geo in
            ZStack {
                // 방 바닥 — 하단 1/3
                RoundedRectangle(cornerRadius: 32)
                    .fill(theme.floorColor)
                    .frame(height: geo.size.height * 0.38)
                    .frame(maxHeight: .infinity, alignment: .bottom)
                    .ignoresSafeArea(edges: .bottom)

                VStack(spacing: 0) {
                    Spacer()

                    // 친구 캐릭터들 — 음악을 듣는 동안만 등장
                    friendsRow
                        .padding(.bottom, 24)

                    // 내 캐릭터 — 하단 중앙
                    myCharacter
                        .padding(.bottom, 36)
                }
                .frame(maxWidth: .infinity)

                if !app.isRealSession {
                    startSessionOverlay
                }
            }
        }
    }

    private var myCharacter: some View {
        CharacterView(
            emoji: AppConfig.characterEmoji,
            name: AppConfig.userId,
            accessory: CharacterAccessory(rawValue: myAccessory) ?? .none,
            trackTitle: app.monitor.currentTrack?.title,
            artistName: app.monitor.currentTrack?.artist,
            isPlaying: app.monitor.isPlaying,
            size: 72
        )
        .onTapGesture { showCustomizeSheet = true }  // 내 캐릭터 탭 = 꾸미기
    }

    private var friendsRow: some View {
        HStack(alignment: .bottom, spacing: 20) {
            if app.roomFriends.isEmpty && app.isRealSession {
                Text("지금 음악을 듣는 친구가 없어요")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .transition(.opacity)
            }
            ForEach(app.roomFriends) { friend in
                CharacterView(
                    emoji: friend.emoji,
                    name: friend.id,
                    accessory: CharacterAccessory(rawValue: friend.accessory ?? "") ?? .none,
                    trackTitle: friend.trackTitle,
                    artistName: friend.artistName,
                    isPlaying: friend.isPlaying,
                    size: 56
                )
                .transition(.scale.combined(with: .opacity))
            }
        }
        // friends 배열이 바뀔 때 삽입/제거에 스프링 애니메이션 적용
        .animation(.spring(duration: 0.5, bounce: 0.4), value: app.roomFriends)
        .frame(minHeight: 110)
    }

    // MARK: - 세션 시작 오버레이

    private var startSessionOverlay: some View {
        VStack(spacing: 14) {
            Text("IpMusic")
                .font(.largeTitle.bold())
            Text("노치에 친구가 산다")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Button {
                Task { await app.startSession() }
            } label: {
                Label("내 음악 세션 시작", systemImage: "music.note.house.fill")
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
            }
            .buttonStyle(.borderedProminent)
            .disabled(app.manager.isSessionActive)

            if !app.manager.areActivitiesEnabled {
                Text("설정 앱에서 Live Activity를 허용해야 세션을 시작할 수 있습니다.")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
        }
        .padding(.vertical, 28)
        .padding(.horizontal, 24)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24))
        .padding(.horizontal, 32)
    }

    // MARK: - 연결 상태

    private var connectionDot: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(app.presence.isConnected ? .green : .gray)
                .frame(width: 8, height: 8)
            Text(app.presence.isConnected ? "연결됨" : "오프라인")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    RoomView()
        .environment(AppModel())
}
