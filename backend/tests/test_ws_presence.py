import time

from fastapi.testclient import TestClient

from app.main import app
from app.presence import PresenceEntry
from app.ws import hub


def _now_playing(track: str = "Ditto", artist: str = "NewJeans") -> dict:
    return {
        "type": "now_playing",
        "track": track,
        "artist": artist,
        "is_playing": True,
        "source": "apple_music",
        "ts": "2026-10-07T12:00:00Z",
    }


def test_friend_receives_playing_and_stop_on_disconnect() -> None:
    client = TestClient(app)
    with client.websocket_connect("/ws?user_id=bob") as bob:
        with client.websocket_connect("/ws?user_id=alice") as alice:
            alice.send_json(_now_playing())
            push = bob.receive_json()
            assert push["type"] == "friend_presence"
            assert push["event"] == "playing"
            assert push["friend_id"] == "alice"
            assert push["emoji"] == "🐰"
            assert push["track"] == "Ditto"
            assert push["is_playing"] is True
        # alice 소켓 종료 → bob에게 stopped push
        push = bob.receive_json()
        assert push["event"] == "stopped"
        assert push["friend_id"] == "alice"


def test_explicit_stopped_report() -> None:
    client = TestClient(app)
    with client.websocket_connect("/ws?user_id=bob") as bob:
        with client.websocket_connect("/ws?user_id=alice") as alice:
            alice.send_json(_now_playing())
            assert bob.receive_json()["event"] == "playing"
            alice.send_json({"type": "stopped", "ts": "2026-10-07T12:01:00Z"})
            push = bob.receive_json()
            assert push["event"] == "stopped"
            assert push["friend_id"] == "alice"


def test_snapshot_on_connect() -> None:
    client = TestClient(app)
    with client.websocket_connect("/ws?user_id=alice") as alice:
        alice.send_json(_now_playing(track="밤편지", artist="아이유"))
        # bob이 늦게 접속해도 alice의 현재 곡 스냅샷을 받는다
        with client.websocket_connect("/ws?user_id=bob") as bob:
            push = bob.receive_json()
            assert push["event"] == "playing"
            assert push["friend_id"] == "alice"
            assert push["track"] == "밤편지"


def test_track_change_pushes_again() -> None:
    client = TestClient(app)
    with client.websocket_connect("/ws?user_id=bob") as bob:
        with client.websocket_connect("/ws?user_id=alice") as alice:
            alice.send_json(_now_playing(track="Ditto"))
            assert bob.receive_json()["track"] == "Ditto"
            alice.send_json(_now_playing(track="OMG"))
            assert bob.receive_json()["track"] == "OMG"


def test_invalid_message_is_ignored() -> None:
    client = TestClient(app)
    with client.websocket_connect("/ws?user_id=bob") as bob:
        with client.websocket_connect("/ws?user_id=alice") as alice:
            alice.send_text("not json at all")
            alice.send_json({"type": "unknown"})
            alice.send_json(_now_playing())
            # 깨진 메시지는 무시되고 정상 보고만 push된다
            assert bob.receive_json()["track"] == "Ditto"


def test_ttl_sweep_removes_expired() -> None:
    hub.store.update(
        "alice",
        PresenceEntry(track="x", artist="y", is_playing=True, source="apple_music"),
    )
    entry = hub.store.get("alice")
    assert entry is not None
    entry.last_seen = time.monotonic() - 1000
    expired = hub.store.sweep_expired(ttl_seconds=90)
    assert expired == ["alice"]
    assert hub.store.get("alice") is None
