# IpMusic — 프로젝트 브리프 (iOS 우선)

> 친구들이 지금 무슨 음악을 듣는지를, 각자의 **캐릭터가 사는 작은 공간**으로 보여주는 소셜 음악 앱.
> 핵심 감성: **"다 같이 한 공간에 있는 느낌"(앰비언트 공존)** — 각자 자기 음악을 듣고, 그게 캐릭터로 공간에 표현된다.

---

## 1. 핵심 컨셉

- 로그인 → 음악 계정(애플뮤직/Spotify) 연동 → **캐릭터 생성·꾸미기**
- 메인 = **나만의 공간**. 친구를 추가하면 그 공간/노치에 친구 캐릭터가 등장
- **음악 기반 presence**: 친구가 *실시간으로 음악을 들을 때만* 캐릭터가 나타나고 무슨 곡인지 표시됨. 안 들으면 사라짐
- **오늘의 최애 곡**: 캐릭터를 탭하면 그 친구가 오늘 들은 곡 중 지정한 최애 곡이 뜸
- **지금 듣는 곡 추천**: 내가 듣는 곡을 친구에게 추천
- **프로필**: 뭘 들었는지 / 가장 많이 들은 것 통계
- **메신저**: 캐릭터 위에 말풍선
- **단톡(2~3명)**: 방 같은 공간에 캐릭터들이 모임
- **노치 / Dynamic Island (앱의 정체성)**: 노치를 누르면 펼쳐지면서, 음악 듣는 친구 캐릭터 + 곡 정보가 뜨고, 말 걸기·추천이 가능

## 2. 차별점 (시장 조사 결과)

비슷한 앱은 이미 있다 — Spotify 자체 'Listening Activity'(실시간+DM+Jam), **Airbuds**(천만 사용자, 친구 실시간 음악+공간 프로필+메신저+통계). 즉 **"기능"은 레드오션**.
하지만 아래는 아무도 안 한 영역 = **우리의 차별점**:

- 꾸민 **캐릭터가 공간에 사는** 형태 (미니홈피/다마고치 감성 — 타일 프로필이 아님)
- 재생을 **캐릭터의 등장/퇴장**으로 표현하는 공간 메타포
- **노치 / Dynamic Island** 연동
- 단톡 = 캐릭터가 모이는 방

→ 파는 가치는 "친구 음악 보기"가 아니라 **"음악으로 채워지는 귀여운 나만의 공간"**.

---

## 3. 확정된 결정사항

| 항목 | 결정 | 이유 |
|---|---|---|
| 1차 플랫폼 | **iOS 전용 먼저** | 사용자 선택 |
| 언어/UI | **Swift + SwiftUI** | 노치·위젯·Live Activity·MusicKit이 전부 네이티브 표면. Flutter는 이 표면들을 못 그려서(데이터 다리만 제공) 이점이 무력화됨 |
| 아키텍처 | **자가보고(self-report)** | 각 클라이언트가 *자기* now-playing만 감지해 백엔드에 보고 → 백엔드가 친구에게 push. 타인 데이터를 Spotify API로 직접 조회하지 않음 → Spotify의 '타인 조회 차단'·쿼터 문제 우회 |
| 음악 소스 | 애플뮤직 + Spotify | 아래 5번 참고 (소스마다 읽는 방식 다름) |
| 노치 표면 | **Live Activities** (ActivityKit + WidgetKit 익스텐션) | iOS에서 Dynamic Island를 쓰는 유일한 공식 경로 |
| 백엔드 | **FastAPI + WebSocket + PostgreSQL** | 사용자가 가장 익숙한 영역. 모든 플랫폼 공용 앵커 |
| 향후 확장 | 맥/안드/윈도우는 **백엔드 공유 + 플랫폼별 네이티브 클라이언트** | 시그니처 표면은 어디서나 네이티브라 클라이언트 통합(Flutter 등) 이점이 작음 |

---

## 4. 기술 스택

**iOS 클라이언트**
- Swift, SwiftUI
- MusicKit (`SystemMusicPlayer.shared.queue.currentEntry`) — 애플뮤직 now-playing 읽기
- ActivityKit + WidgetKit 익스텐션 (SwiftUI) — Dynamic Island / Live Activity UI
- (보조) WidgetKit 홈 화면 위젯 — 상시 글랜스
- URLSession/WebSocket — 백엔드 통신

**백엔드**
- FastAPI (Python)
- WebSocket — presence/메시지 실시간 push
- PostgreSQL (Docker)
- Spotify OAuth + Web API 폴링 (Spotify 유저의 now-playing은 서버가 가져옴)

---

## 5. iOS 특이사항·제약 (정확히 알고 갈 것)

**음악 읽기 — 소스마다 다름**
- **애플뮤직**: 기기에서 로컬로 읽을 수 있음 (MusicKit / `MPMusicPlayerController.systemMusicPlayer`). 단 **애플뮤직 앱 전용** — Spotify 등 서드파티 앱은 iOS에서 로컬로 못 읽음 (맥의 MediaRemote 같은 만능 감지가 iOS엔 없음)
- **Spotify**: 백엔드가 Spotify Web API(`/me/player/currently-playing`, 사용자 OAuth)를 **폴링**. 폰이 깨어있지 않아도 서버가 가져올 수 있음(오히려 장점)

**Live Activities / Dynamic Island**
- iOS 16.1+. 앱 또는 서버(APNs `liveactivity` push)로 갱신. iOS 17.2+는 push-to-start 가능
- **세션형**: 최대 8시간 활성(이후 Dynamic Island에서 사라짐, 잠금화면 최대 12시간). "영구 위젯"이 아니라 이벤트에 묶인 세션
- 데이터 페이로드 4KB 제한, 업데이트 빈도 예산 있음 → 3초마다 같은 잦은 push는 드롭됨. 곡은 ~3분마다 바뀌니 *곡 변경/접속·이탈 시 갱신*이면 충분
- 잦은 갱신 필요 시 Info.plist `NSSupportsLiveActivitiesFrequentUpdates` = YES, priority 5/10 혼용
- → 설계: "IpMusic 세션 켜기"로 Live Activity 시작 → 노치에 떠 있음, 8h 후 push-to-start로 재시작

**계정·서명**
- 무료 Apple 계정으로 실기기 빌드/로컬 Live Activity 갱신 테스트는 가능
- 배포 + APNs push 업데이트 + 안정적 실기기 테스트는 **유료 Apple Developer 멤버십(연 99달러 수준 — 가입 시 현재가 확인)** 필요
- Dynamic Island 확인엔 해당 기종 **시뮬레이터** 또는 실기기 필요

---

## 6. MVP 마일스톤 (작게 쪼개기 → 매번 커밋)

- **M0 — "노치에 내 음악이 산다"** (백엔드 0, 혼자)
  애플뮤직 now-playing 감지 → Live Activity로 Dynamic Island에 내 캐릭터 + 곡 표시. 핵심 감성 즉시 검증. *첫 목표.*
- **M1 — 친구 1명 등장**
  FastAPI + WebSocket. 친구 상태가 백엔드 통해 들어와 공간/노치에 캐릭터 등장·퇴장 + 곡 표시. (Spotify 유저용 서버 폴링도 여기서)
- **M2 — 상호작용**
  캐릭터 꾸미기, 말풍선/메시지, 지금 듣는 곡 추천, 앱 내 전체화면 공간 UI
- **M3 — 사회화**
  친구 시스템 + 인증 + Spotify OAuth 로그인, 단톡(2~3명), 프로필 통계
- **Phase 2 — 확장**
  맥(노치 패널) / 안드로이드(오버레이·버블) / 윈도우(플로팅 위젯). 백엔드·캐릭터 에셋 재사용

> 의도된 전체 사용자 흐름(참고): 로그인 → 음악계정 연동 → 캐릭터 꾸미기 → 메인 공간 → 친구 추가 → presence/추천/메신저/단톡/노치.
> MVP는 이 흐름을 거꾸로, 가장 마법 같은 조각(M0)부터 만든다.

---

## 7. 작업 방식 — 토큰/컨텍스트 관리

- **CLAUDE.md는 가볍게** (A4 한 장). 매번 알아야 할 것만: 스택, 빌드/테스트 명령, 핵심 컨벤션, 디렉토리 규칙, "하지 말 것". 장황한 설명은 별도 문서로 빼고 참조만. 자주 안 바뀌면 캐싱돼 절약됨
- **`/clear` 리듬**: 작업 단위 작게 → 끝나면 커밋 → `/clear` → 다음. (CV의 GPU 메모리 비우기와 같음)
- 큰 로그/파일 통째로 넣지 말기. `... | tail -50`처럼 잘라서. 탐색은 서브에이전트로 오프로딩
- **Plan Mode(Shift+Tab)**로 큰 기능은 계획부터 → 코드 엎는 낭비 방지
- Git: 기능 하나 완성마다 커밋 = 안전벨트

---

## 8. 참고 자료

- **Airbuds Widget** — 컨셉 벤치마크(친구 실시간 음악 + 공간 프로필 + 메신저 + 통계)
- **Music Presence** (`ungive/discord-music-presence`) — 로컬 now-playing 감지 → 외부 보고 패턴. 자가보고 아키텍처의 실증 사례
- **Live Activities 가이드** — ActivityKit / WidgetKit 익스텐션 / APNs liveactivity push
- (반면교사) Flutter `live_activities` 플러그인 — Dynamic Island UI는 결국 SwiftUI로 짜야 함을 확인

---

## 9. 다음 단계

Claude Code에서 `claude` 실행 → `Shift+Tab`(Plan Mode) → 아래 프롬프트로 시작:

```
IpMusic이라는 iOS 네이티브 앱을 만들 거야. 아직 코드는 짜지 말고 계획부터 세우자.

[컨셉] 아이폰 Dynamic Island를 눌러 펼치면 친구 캐릭터들이 사는 공간이 나온다.
각자 자기 음악을 듣고 있을 때만 그 친구의 캐릭터가 나타나고 무슨 곡인지 보인다.
말을 걸 수 있고, 내가 지금 듣는 곡을 친구에게 추천할 수 있다. 핵심 감성은
"다 같이 한 공간에 있는 느낌"(앰비언트 공존)이다.

[확정] iOS 전용 먼저 / Swift + SwiftUI / Live Activities(ActivityKit+WidgetKit)로
노치 구현 / 아키텍처는 자가보고(각 클라이언트가 자기 now-playing 감지→백엔드→
친구에게 WebSocket push) / 애플뮤직은 MusicKit systemMusicPlayer로 로컬 감지,
Spotify는 백엔드가 Web API 폴링 / 백엔드 FastAPI + WebSocket + PostgreSQL(Docker).

[내 배경] computer vision 엔지니어. C++/Python/백엔드/Docker/Git 익숙.
Swift·SwiftUI·바이브코딩은 처음.

[부탁]
1. 위 방향 검토 + 더 나은 대안 제안.
2. 전체 디렉토리 구조(iOS 앱 + WidgetKit 익스텐션 + 백엔드) 제안.
3. 가장 먼저 만들 M0("애플뮤직 now-playing을 감지해 Dynamic Island에 내 캐릭터+곡
   표시", 백엔드 없이 혼자 동작)의 구체적 작업 목록.
계획 확정되면 CLAUDE.md 만들고 M0부터 구현 시작.
```