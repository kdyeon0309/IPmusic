"""M2 곡 추천 테스트 — 인메모리 repo 기준 (DB 모드는 lifespan에서 승격)."""

from fastapi.testclient import TestClient

from app.main import app
from app.recommendations import RecommendationRepo
from app.ws import hub


def _recommend(to: str, track: str = "Super Shy", store_id: str = "1694530913") -> dict:
    return {
        "type": "recommend",
        "to": to,
        "track": track,
        "artist": "NewJeans",
        "store_id": store_id,
        "ts": "2026-10-07T12:00:00Z",
    }


def _fresh_repo() -> None:
    """전역 hub를 쓰므로 테스트마다 추천 저장소를 초기화한다."""
    hub.reco_repo = RecommendationRepo()


def test_online_recipient_gets_push_immediately() -> None:
    _fresh_repo()
    client = TestClient(app)
    with client.websocket_connect("/ws?user_id=bob") as bob:
        with client.websocket_connect("/ws?user_id=alice") as alice:
            alice.send_json(_recommend("bob"))
            push = bob.receive_json()
            assert push["type"] == "friend_recommendation"
            assert push["from_id"] == "alice"
            assert push["from_emoji"] == "🐰"
            assert push["track"] == "Super Shy"
            assert push["store_id"] == "1694530913"
            assert isinstance(push["id"], int)


def test_offline_recipient_gets_pending_on_connect() -> None:
    _fresh_repo()
    client = TestClient(app)
    with client.websocket_connect("/ws?user_id=alice") as alice:
        alice.send_json(_recommend("bob", track="밤편지"))
        # bob이 늦게 접속해도 pending으로 전달된다
        with client.websocket_connect("/ws?user_id=bob") as bob:
            push = bob.receive_json()
            assert push["type"] == "friend_recommendation"
            assert push["track"] == "밤편지"


def test_acked_recommendation_not_redelivered() -> None:
    _fresh_repo()
    client = TestClient(app)
    with client.websocket_connect("/ws?user_id=alice") as alice:
        alice.send_json(_recommend("bob"))
        with client.websocket_connect("/ws?user_id=bob") as bob:
            push = bob.receive_json()
            bob.send_json({
                "type": "recommendation_ack",
                "recommendation_id": push["id"],
                "ts": "2026-10-07T12:01:00Z",
            })
        # ack 후 재접속 → 아무것도 오지 않아야 한다.
        # 수신 대기 대신, alice의 now_playing push가 '첫 메시지'로 오는지 본다.
        with client.websocket_connect("/ws?user_id=bob") as bob:
            alice.send_json({
                "type": "now_playing", "track": "Ditto", "artist": "NewJeans",
                "is_playing": True, "source": "apple_music", "ts": "2026-10-07T12:02:00Z",
            })
            push = bob.receive_json()
            assert push["type"] == "friend_presence"


def test_recommendation_to_non_friend_is_ignored() -> None:
    _fresh_repo()
    client = TestClient(app)
    with client.websocket_connect("/ws?user_id=alice") as alice:
        alice.send_json(_recommend("mallory"))
        # mallory가 접속해도 pending이 없어야 한다 → 첫 push가 추천이 아님을 보장
        with client.websocket_connect("/ws?user_id=mallory") as mallory:
            # mallory는 친구가 없어 스냅샷도 비었다. 라운드트립 확인용으로
            # 잘못된 메시지를 보내도 연결이 살아 있는지만 본다.
            mallory.send_json({"type": "stopped", "ts": "2026-10-07T12:03:00Z"})
    # 저장소에도 남지 않아야 한다
    import asyncio

    pending = asyncio.run(hub.reco_repo.pending_for("mallory"))
    assert pending == []
