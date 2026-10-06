import MediaPlayer
import SwiftUI

/// 받은 곡 추천 UI — 방 구석의 🎁 선물상자(개수 뱃지)와 상세 시트.
struct RecommendationBox: View {
    @Environment(AppModel.self) private var app
    @State private var showSheet = false

    var body: some View {
        if !app.presence.pendingRecommendations.isEmpty {
            Button {
                showSheet = true
            } label: {
                ZStack(alignment: .topTrailing) {
                    Text("🎁")
                        .font(.system(size: 44))
                        .shadow(color: .black.opacity(0.15), radius: 5, y: 3)
                    Text("\(app.presence.pendingRecommendations.count)")
                        .font(.caption2.bold())
                        .foregroundStyle(.white)
                        .padding(5)
                        .background(.red, in: Circle())
                        .offset(x: 6, y: -6)
                }
            }
            .buttonStyle(.plain)
            .transition(.scale.combined(with: .opacity))
            .sheet(isPresented: $showSheet) {
                RecommendationListSheet()
            }
        }
    }
}

/// 받은 추천 목록 시트 — 듣기(ack 동반) / 확인(ack).
struct RecommendationListSheet: View {
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List(app.presence.pendingRecommendations) { reco in
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        Text(reco.fromEmoji)
                            .font(.title2)
                        Text("\(reco.fromId)님이 곡을 추천했어요")
                            .font(.subheadline.weight(.semibold))
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(reco.track)
                            .font(.headline)
                            .lineLimit(1)
                        Text(reco.artist)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    HStack {
                        Button {
                            listen(to: reco)
                        } label: {
                            Label("Apple Music에서 듣기", systemImage: "play.fill")
                                .font(.subheadline)
                        }
                        .buttonStyle(.borderedProminent)

                        Button("확인") {
                            ack(reco)
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .padding(.vertical, 6)
            }
            .navigationTitle("받은 추천")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("닫기") { dismiss() }
                }
            }
            .onChange(of: app.presence.pendingRecommendations.isEmpty) { _, empty in
                if empty { dismiss() }
            }
        }
    }

    /// 재생 시도: storeID가 있으면 시스템 플레이어 큐 교체(Apple Music 구독 필요),
    /// 실패/부재 시 Apple Music 웹 링크로 폴백. 어느 쪽이든 ack 처리.
    private func listen(to reco: FriendRecommendation) {
        if let storeId = reco.storeId {
            let player = MPMusicPlayerController.systemMusicPlayer
            player.setQueue(with: [storeId])
            player.play()
            // setQueue 실패(무구독 등)는 콜백이 없어 감지 불가 — 웹 링크를 보조로 열지는 않고,
            // 재생이 안 되면 사용자가 다시 탭해 아래 검색 폴백을 쓰도록 한다.
        } else {
            let query = "\(reco.track) \(reco.artist)"
                .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            if let url = URL(string: "https://music.apple.com/kr/search?term=\(query)") {
                UIApplication.shared.open(url)
            }
        }
        ack(reco)
    }

    private func ack(_ reco: FriendRecommendation) {
        app.presence.ackRecommendation(id: reco.id)
    }
}
