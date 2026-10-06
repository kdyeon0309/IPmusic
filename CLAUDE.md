# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 프로젝트 상태
- **M0·M1 완료** (M1: 친구 presence가 백엔드 경유로 노치/앱에 등장·퇴장 — 실기기 엔드투엔드 검증 2026-10-07). 원본 스펙: `docs/BRIEF.md`. 다음: **M2** (캐릭터 꾸미기·말풍선·곡 추천·공간 UI) 또는 M1 잔여 optional인 Spotify 폴링 워커(WU8).

## 제품 한 줄
친구의 실시간 음악 presence를 **캐릭터가 사는 공간 + Dynamic Island**로 보여주는 iOS 소셜 음악 앱. 파는 가치는 "친구 음악 보기"가 아니라 "음악으로 채워지는 나만의 공간".

## 스택
- **iOS**: Swift + SwiftUI · MusicKit · ActivityKit + WidgetKit 익스텐션 · URLSession/WebSocket
- **백엔드**: FastAPI + WebSocket + PostgreSQL(Docker) · Spotify OAuth + Web API

## 아키텍처 핵심 (여러 파일에 걸쳐 알아야 할 것)
- **자가보고(self-report)**: 각 클라이언트가 *자기* now-playing만 감지 → 백엔드 → 친구에게 WebSocket push. 타인 데이터를 Spotify API로 직접 조회하지 않는다.
- **음악 소스 비대칭**: 애플뮤직은 iOS 기기에서 **로컬** 감지(MusicKit `systemMusicPlayer`). Spotify는 **백엔드가 Web API 폴링**(`/me/player/currently-playing`). iOS는 서드파티 앱 로컬 감지 불가.
- **Dynamic Island = Live Activities**(ActivityKit, iOS 16.1+). 영구 위젯이 아니라 **세션형**(최대 8h). 페이로드 **4KB** 제한 + 업데이트 빈도 예산 → *곡 변경 / 친구 접속·이탈* 시에만 갱신.

## 개발 명령
- iOS 프로젝트 생성 (project.yml 변경 시 재실행): `cd ios && xcodegen generate`
- iOS 빌드: `cd ios && xcodebuild -project IpMusic.xcodeproj -scheme IpMusic -destination 'generic/platform=iOS Simulator' build`
- 실기기 빌드: 위 명령에 `-destination 'platform=iOS,id=<기기ID>' -allowProvisioningUpdates` (기기 ID는 `xcrun devicectl list devices`)
- 실기기 설치/실행: `xcrun devicectl device install app --device <기기ID> <DerivedData의 .app 경로>` / `xcrun devicectl device process launch --device <기기ID> com.kdyeon.ipmusic`
- 빠른 타입 검사 (시뮬레이터 런타임 불필요): `cd ios && swiftc -typecheck -sdk $(xcrun --sdk iphonesimulator --show-sdk-path) -target arm64-apple-ios17.0-simulator IpMusic/*.swift IpMusic/LiveActivity/*.swift IpMusic/NowPlaying/*.swift IpMusic/Networking/*.swift IpMusic/Presence/*.swift Shared/*.swift` (위젯은 `-parse-as-library IpMusicWidget/*.swift Shared/*.swift`)
- iOS 테스트: _TBD_ (XCTest 예정)
- 백엔드 실행: `cd backend && uv run uvicorn app.main:app --reload --host 0.0.0.0` (실기기 접속엔 `--host 0.0.0.0` 필수)
- 백엔드 테스트: `cd backend && uv run pytest` (단일: `uv run pytest tests/test_ws_presence.py -k 이름`)
- 로컬 DB: `cd backend && docker compose up -d` → 시드: `uv run python -m app.seed`
- 친구 시뮬레이터 (솔로 테스트): `cd backend && uv run python scripts/friend_sim.py --track "밤편지" --artist "아이유"`

## 작업 방식
- 큰 기능은 **Plan Mode (Shift+Tab)**로 계획부터 → 코드 엎는 낭비 방지.
- 작업 단위 작게 → **완성마다 커밋** → `/clear` → 다음.
- 큰 로그/파일 통째로 넣지 말고 잘라서(`... | tail -50`). 넓은 탐색은 서브에이전트로 오프로딩.
- CLAUDE.md는 가볍게 유지. 장황한 설명은 `docs/`로 빼고 여기선 참조만.

## 주의
- **실기기는 `localhost` 불가** — `ios/IpMusic/AppConfig.swift`의 serverHost를 Mac LAN IP(`ipconfig getifaddr en0`)로. 시뮬레이터는 localhost 자동 사용.
- **ContentState(`Shared/MusicActivityAttributes.swift`) 변경 시 앱+위젯 동시 재빌드** — Codable 불일치면 Live Activity 갱신이 조용히 실패.
- M1 인증 없음: 내 user_id는 `alice` 고정(AppConfig), 친구 시뮬레이터는 `bob`. DB 시드: `app/seed.py`.

## 하지 말 것
- 타인 now-playing을 Spotify API로 **직접 조회**하지 말 것 (자가보고 원칙 위반 + 쿼터/차단).
- Dynamic Island에 몇 초마다 같은 잦은 push 금지 (드롭됨).
- Flutter 등으로 노치 / Live Activity UI를 대체하려 하지 말 것 — 이 표면은 **네이티브 SwiftUI 필수**.

## 개발자 배경
CV 엔지니어. C++/Python/백엔드/Docker/Git 익숙, **Swift·SwiftUI는 처음**. → SwiftUI·iOS 네이티브 관련은 더 설명적으로.
