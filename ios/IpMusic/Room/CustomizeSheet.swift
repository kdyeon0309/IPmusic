import SwiftUI

/// 내 캐릭터 꾸미기 시트 — 악세사리 + 방 테마 프리셋 선택.
///
/// 저장: `@AppStorage`(UserDefaults를 뷰 상태처럼 쓰는 래퍼 — 앱 재시작에도 유지)에
/// 즉시 반영하고, 서버에는 sendCustomization으로 전파해 친구 화면에도 반영시킨다.
struct CustomizeSheet: View {
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss

    @AppStorage("myAccessory") private var myAccessory = ""
    @AppStorage("myRoomTheme") private var myRoomTheme = RoomTheme.cream.rawValue

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    preview
                    accessoryPicker
                    themePicker
                }
                .padding()
            }
            .navigationTitle("꾸미기")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("완료") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    // MARK: - 미리보기

    private var preview: some View {
        let theme = RoomTheme(rawValue: myRoomTheme) ?? .cream
        return VStack(spacing: 8) {
            CharacterView(
                emoji: AppConfig.characterEmoji,
                name: AppConfig.userId,
                accessory: CharacterAccessory(rawValue: myAccessory) ?? .none,
                size: 72
            )
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(
            LinearGradient(colors: theme.wallColors, startPoint: .top, endPoint: .bottom),
            in: RoundedRectangle(cornerRadius: 20)
        )
        .environment(\.colorScheme, theme.isDark ? .dark : .light)
    }

    // MARK: - 악세사리

    private var accessoryPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("악세사리")
                .font(.headline)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(CharacterAccessory.allCases) { accessory in
                        Button {
                            select(accessory: accessory)
                        } label: {
                            VStack(spacing: 4) {
                                Text(accessory.overlayEmoji ?? "✖️")
                                    .font(.title2)
                                Text(accessory.displayName)
                                    .font(.caption2)
                            }
                            .frame(width: 64, height: 64)
                            .background(
                                myAccessory == accessory.rawValue
                                    ? Color.accentColor.opacity(0.2)
                                    : Color(.systemGray6),
                                in: RoundedRectangle(cornerRadius: 14)
                            )
                            .overlay {
                                if myAccessory == accessory.rawValue {
                                    RoundedRectangle(cornerRadius: 14)
                                        .strokeBorder(Color.accentColor, lineWidth: 2)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // MARK: - 방 테마

    private var themePicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("방 테마")
                .font(.headline)
            HStack(spacing: 12) {
                ForEach(RoomTheme.allCases) { theme in
                    Button {
                        select(theme: theme)
                    } label: {
                        VStack(spacing: 4) {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: theme.wallColors,
                                        startPoint: .top, endPoint: .bottom
                                    )
                                )
                                .frame(width: 40, height: 40)
                                .overlay {
                                    Circle().strokeBorder(
                                        myRoomTheme == theme.rawValue ? Color.accentColor : .gray.opacity(0.3),
                                        lineWidth: myRoomTheme == theme.rawValue ? 3 : 1
                                    )
                                }
                            Text(theme.displayName)
                                .font(.caption2)
                                .foregroundStyle(.primary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - 저장 + 서버 전파

    private func select(accessory: CharacterAccessory) {
        myAccessory = accessory.rawValue
        app.presence.sendCustomization(accessory: myAccessory, roomTheme: myRoomTheme)
    }

    private func select(theme: RoomTheme) {
        myRoomTheme = theme.rawValue
        app.presence.sendCustomization(accessory: myAccessory, roomTheme: myRoomTheme)
    }
}

#Preview {
    CustomizeSheet()
        .environment(AppModel())
}
