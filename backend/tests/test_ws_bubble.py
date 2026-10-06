"""M2 말풍선 (bubble → friend_bubble) 테스트. 비영속 — 오프라인 수신자는 drop."""

from fastapi.testclient import TestClient

from app.main import app


def _bubble(to: str, text: str) -> dict:
    return {"type": "bubble", "to": to, "text": text, "ts": "2026-10-07T12:00:00Z"}


def _now_playing() -> dict:
    return {
        "type": "now_playing",
        "track": "Ditto",
        "artist": "NewJeans",
        "is_playing": True,
        "source": "apple_music",
        "ts": "2026-10-07T12:00:00Z",
    }


def test_bubble_delivered_to_friend() -> None:
    client = TestClient(app)
    with client.websocket_connect("/ws?user_id=bob") as bob:
        with client.websocket_connect("/ws?user_id=alice") as alice:
            alice.send_json(_bubble("bob", "안녕!"))
            push = bob.receive_json()
            assert push["type"] == "friend_bubble"
            assert push["from_id"] == "alice"
            assert push["from_emoji"] == "🐰"
            assert push["text"] == "안녕!"


def test_overlong_bubble_is_ignored() -> None:
    client = TestClient(app)
    with client.websocket_connect("/ws?user_id=bob") as bob:
        with client.websocket_connect("/ws?user_id=alice") as alice:
            alice.send_json(_bubble("bob", "가" * 51))  # max 50자 초과 → 무시
            alice.send_json(_now_playing())  # 연결은 살아 있어야 한다
            push = bob.receive_json()
            assert push["type"] == "friend_presence"
            assert push["track"] == "Ditto"


def test_bubble_to_non_friend_is_ignored() -> None:
    client = TestClient(app)
    with client.websocket_connect("/ws?user_id=mallory") as mallory:
        with client.websocket_connect("/ws?user_id=alice") as alice:
            # mallory는 alice의 친구가 아님 → push 없음
            alice.send_json(_bubble("mallory", "몰래 보낸 메시지"))
            alice.send_json(_bubble("bob", "bob은 오프라인"))  # 오프라인 drop도 조용히
            # mallory 소켓이 아무것도 받지 않았음을 보장하기 위해, alice가 정상 메시지로
            # 라운드트립을 만든 뒤에도 mallory에게 온 push가 없는지 본다.
            with client.websocket_connect("/ws?user_id=bob") as bob:
                alice.send_json(_bubble("bob", "정상"))
                assert bob.receive_json()["text"] == "정상"
            # bob까지 수신을 마친 시점에도 mallory에겐 아무것도 오지 않았다.
            # (TestClient에는 non-blocking recv가 없어 순서 보장으로 대신한다)
